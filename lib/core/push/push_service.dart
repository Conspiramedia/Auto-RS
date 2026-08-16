// ============================================================
// AUTO.RS — Push-уведомления (FCM).
//
// Что делает сервис:
//   * инициализирует Firebase и подписывается на обновление токена;
//   * регистрирует токен устройства за пользователем (RPC register_push_token);
//   * обрабатывает тап по уведомлению → переход на нужный экран.
//
// РАЗДЕЛЕНИЕ ОТВЕТСТВЕННОСТИ. Сервер (Пакет C) кладёт задания в push_queue,
// Edge Function send-push их отправляет. Клиент отвечает только за две вещи:
// сообщить свой токен и правильно отреагировать на тап. Никакой логики
// «кому и когда слать» здесь нет и быть не должно.
//
// PAYLOAD. Триггеры кладут в data цель перехода (миграция 0045):
//   car_id  — объявление: saved_search, price_drop;
//   chat_id — переписка: new_message (там же есть car_id).
// Приоритет у chat_id: если пришло сообщение, человек ждёт именно чат,
// а не карточку машины.
//
// ТОКЕН И АККАУНТ. Токен привязывается к пользователю на сервере, поэтому
// регистрировать его имеет смысл только после входа. При выходе токен
// отвязывается — иначе следующий владелец устройства получал бы чужие пуши.
// ============================================================

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/saved_searches_repository.dart';
import '../routing/app_router.dart';

// Обработчик фоновых сообщений. ОБЯЗАН быть функцией верхнего уровня с
// аннотацией @pragma: Flutter поднимает для него отдельный изолят, и ссылку
// на метод класса туда передать нельзя.
//
// Тело намеренно пустое: показ системного уведомления берёт на себя FCM
// (сообщения отправляются с блоком notification), а переход по тапу
// обрабатывается уже в основном изоляте — см. _handleMessage.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Регистрация обработчика обязательна, даже если работы нет: без неё
  // Android выводит предупреждение и часть событий теряется.
}

class PushService {
  PushService._();

  static final PushService instance = PushService._();

  final _auth = AuthRepository();
  final _searches = SavedSearchesRepository();

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<dynamic>? _authSub;

  bool _initialized = false;

  // ----------------------------------------------------------
  // Инициализация. Вызывается один раз из main() ДО runApp.
  //
  // Ошибки гасим: приложение обязано запуститься даже без Firebase
  // (нет сети при первом старте, повреждён конфиг, отключённый сервис
  // Google Play на устройстве). Пуши — не критичная для работы функция.
  // ----------------------------------------------------------
  Future<void> init() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // Токен меняется при переустановке приложения и иногда сам по себе.
      // Без подписки на обновление устройство однажды перестало бы получать
      // уведомления молча.
      _tokenSub = messaging.onTokenRefresh.listen(_registerToken);

      // Тап по уведомлению, когда приложение работало в фоне.
      _openedSub =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

      // Тап по уведомлению, когда приложение было выгружено: сообщение
      // ждёт в getInitialMessage и доставляется один раз при запуске.
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        // Откладываем на следующий кадр: роутер ещё не построен, и
        // немедленный переход потерялся бы.
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _handleMessage(initial));
      }

      // Вход мог произойти в любой момент — регистрируем токен и при
      // старте (если сессия уже есть), и при каждой смене авторизации.
      _authSub = _auth.authStateChanges.listen((_) => syncToken());
      await syncToken();

      _initialized = true;
    } catch (e) {
      // Firebase недоступен — приложение работает без пушей.
      debugPrint('PushService: инициализация не удалась: $e');
    }
  }

  // ----------------------------------------------------------
  // Запрос разрешения у пользователя.
  //
  // Вызывается ПОСЛЕ третьего шага онбординга (см. push_permission_sheet):
  // системный диалог iOS показывается один раз за установку, и спросив его
  // вслепую на старте, отказ уже не переиграть.
  //
  // Возвращает true, если пользователь разрешил уведомления.
  // ----------------------------------------------------------
  Future<bool> requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();

      final granted = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          // provisional — «тихие» уведомления iOS без явного согласия:
          // они доставляются, поэтому токен регистрировать нужно.
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (granted) await syncToken();
      return granted;
    } catch (e) {
      debugPrint('PushService: запрос разрешения не удался: $e');
      return false;
    }
  }

  // ----------------------------------------------------------
  // Регистрация текущего токена за вошедшим пользователем.
  //
  // Безопасно вызывать многократно: сервер делает upsert по токену, а при
  // смене аккаунта на устройстве токен переезжает к новому владельцу.
  // ----------------------------------------------------------
  Future<void> syncToken() async {
    // Гостю регистрировать нечего: токен привязывается к auth.uid().
    if (_auth.currentUser == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
    } catch (e) {
      debugPrint('PushService: получение токена не удалось: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    if (_auth.currentUser == null) return;

    try {
      await _searches.registerPushToken(
        token,
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      );
    } catch (e) {
      debugPrint('PushService: регистрация токена не удалась: $e');
    }
  }

  // ----------------------------------------------------------
  // Отвязка токена при выходе из аккаунта.
  //
  // Вызывать ДО signOut: после выхода auth.uid() уже пуст, и серверная
  // функция не найдёт, чей это токен.
  // ----------------------------------------------------------
  Future<void> unregisterToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _searches.unregisterPushToken(token);
    } catch (e) {
      debugPrint('PushService: отвязка токена не удалась: $e');
    }
  }

  // ----------------------------------------------------------
  // Переход по тапу на уведомление.
  //
  // Навигация идёт через глобальный роутер, а не через BuildContext: тап
  // приходит извне дерева виджетов, и подходящего контекста в этот момент
  // просто нет.
  // ----------------------------------------------------------
  void _handleMessage(RemoteMessage message) {
    final data = message.data;

    final chatId = data['chat_id'];
    final carId = data['car_id'];

    // Приоритет чату: при новом сообщении человек ждёт переписку,
    // а не карточку объявления (хотя car_id в payload тоже есть).
    if (chatId is String && chatId.isNotEmpty) {
      AppRouter.router.push('/chat/$chatId');
      return;
    }

    if (carId is String && carId.isNotEmpty) {
      AppRouter.router.push('/car/$carId');
    }
  }

  // Освобождение подписок. В обычной жизни приложения не вызывается
  // (сервис живёт столько же, сколько процесс), но нужен для тестов.
  void dispose() {
    _tokenSub?.cancel();
    _openedSub?.cancel();
    _authSub?.cancel();
    _initialized = false;
  }
}

// ============================================================
// AUTO.RS — Сервис онбординга: показывать ли приветственные шаги.
//
// ЗАЧЕМ ЛОКАЛЬНО, А НЕ В profiles: онбординг проходит ГОСТЬ — аккаунт
// создаётся только по SMS-коду в момент публикации объявления или входа.
// Записать «онбординг пройден» в profiles на этом этапе некуда, поэтому
// факт прохождения храним на устройстве, как это уже сделано для согласия
// с политикой (см. ConsentService).
//
// Существующее поле profiles.role_selected решает другую задачу — выбор
// роли покупатель/продавец у авторизованного пользователя, и мы его не
// трогаем: онбординг лишь подсказывает роль, окончательно её фиксирует
// selectRole после входа.
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  OnboardingService._();

  static final OnboardingService instance = OnboardingService._();

  // Версия онбординга. Подняв её, можно показать обновлённые шаги всем —
  // включая тех, кто проходил старую версию.
  static const int _version = 1;
  static const _keyCompleted = 'onboarding_completed_version';
  // Разрешение на пуши спрашиваем ОДИН раз: повторные показы системного
  // диалога на iOS всё равно игнорируются, а свой экран раздражает.
  static const _keyPushAsked = 'onboarding_push_asked';

  // Кэш в памяти: главный экран проверяет флаг при каждом запуске, и лишний
  // поход на диск в первом кадре заметен.
  bool? _completedCache;

  // Пройден ли онбординг текущей версии.
  Future<bool> isCompleted() async {
    final cached = _completedCache;
    if (cached != null) return cached;

    try {
      final sp = await SharedPreferences.getInstance();
      final result = sp.getInt(_keyCompleted) == _version;
      _completedCache = result;
      return result;
    } catch (_) {
      // Диск недоступен — не блокируем вход в приложение, считаем пройденным.
      return true;
    }
  }

  // Отметить онбординг пройденным (в том числе при пропуске).
  Future<void> markCompleted() async {
    _completedCache = true;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(_keyCompleted, _version);
    } catch (_) {
      // Не сохранилось — онбординг покажется ещё раз при следующем запуске.
    }
  }

  // Спрашивали ли уже разрешение на уведомления.
  Future<bool> wasPushAsked() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getBool(_keyPushAsked) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markPushAsked() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_keyPushAsked, true);
    } catch (_) {
      // Не сохранилось — спросим ещё раз, не критично.
    }
  }
}

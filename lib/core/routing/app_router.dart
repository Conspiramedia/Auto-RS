// ============================================================
// AUTO.RS — Маршрутизация приложения (go_router).
// Реактивный редирект: неавторизованный на защищённые экраны
// перенаправляется на /login. Каталог доступен и гостю.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/car_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../features/admin/screens/moderation_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/catalog/screens/car_detail_screen.dart';
import '../../features/chat/screens/chat_room_screen.dart';
import '../../features/chat/screens/chats_list_screen.dart';
import '../../features/favorites/screens/favorites_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/catalog/screens/catalog_screen.dart';
import '../../features/legal/screens/policy_screen.dart';
import '../../features/listings/screens/create_car_screen.dart';
import '../../features/listings/screens/my_cars_screen.dart';
import '../../features/profile/screens/dealer_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/wallet_screen.dart';
import '../../shared/screens/home_shell.dart';

class AppRouter {
  AppRouter._();

  static final _auth = AuthRepository();

  // Стартовый маршрут. Онбординг показывается только при первом запуске:
  // флаг читается с диска в main() ДО создания роутера (проверка
  // асинхронная, а redirect у go_router синхронный — держать в нём
  // обращение к диску нельзя).
  static bool showOnboarding = false;

  static final GoRouter router = GoRouter(
    initialLocation: showOnboarding ? '/onboarding' : '/catalog',
    // Роутер пересобирается при смене состояния авторизации
    refreshListenable: _AuthNotifier(_auth),
    routes: [
      // Онбординг — первый запуск, вне нижней навигации.
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        // extra — необязательный префилл телефона (например, из формы
        // объявления: контактный номер сразу подставляется в поле входа).
        builder: (context, state) =>
            LoginScreen(prefillPhone: state.extra as String?),
      ),
      // Детали авто — полноэкранный, вне нижней навигации
      GoRoute(
        path: '/car/:id',
        builder: (context, state) =>
            CarDetailScreen(carId: state.pathParameters['id']!),
      ),
      // Создание объявления — требует авторизации (см. redirect ниже)
      GoRoute(
        path: '/create-car',
        builder: (context, state) => const CreateCarScreen(),
      ),
      // Редактирование объявления — editCar передаётся через extra.
      GoRoute(
        path: '/edit-car',
        builder: (context, state) =>
            CreateCarScreen(editCar: state.extra as CarModel?),
      ),
      // Дублирование: форма заполнена полями исходного объявления, но
      // сохранение создаёт НОВОЕ (в отличие от /edit-car).
      GoRoute(
        path: '/duplicate-car',
        builder: (context, state) =>
            CreateCarScreen(duplicateFrom: state.extra as CarModel?),
      ),
      // Мои объявления (продавец) — требует авторизации
      // Витрина продавца. Доступна гостю: человек может прийти по прямой
      // ссылке, и требовать вход ради просмотра салона незачем.
      GoRoute(
        path: '/dealer/:id',
        builder: (context, state) =>
            DealerScreen(sellerId: state.pathParameters['id']!),
      ),
      // Кошелёк: баланс и история операций.
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/my-cars',
        builder: (context, state) => const MyCarsScreen(),
      ),
      // Модерация — требует авторизации (доступ к данным закрыт RLS/RPC для не-админов)
      GoRoute(
        path: '/moderation',
        builder: (context, state) => const ModerationScreen(),
      ),
      // Уведомления — требует авторизации
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      // Политика и условия — просмотр (доступен всем, в т.ч. гостю).
      GoRoute(
        path: '/policy',
        builder: (context, state) => const PolicyScreen(),
      ),
      // Чат-комната — требует авторизации. peerName передаётся через extra.
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) => ChatRoomScreen(
          chatId: state.pathParameters['id']!,
          peerName: state.extra as String?,
        ),
      ),
      // Основной каркас с нижней навигацией
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/catalog',
            builder: (context, state) => const CatalogScreen(),
          ),
          GoRoute(
            path: '/favorites',
            builder: (context, state) => const FavoritesScreen(),
          ),
          GoRoute(
            path: '/chats',
            builder: (context, state) => const ChatsListScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
    // Логика доступа: /profile требует авторизации; /login недоступен уже вошедшим
    redirect: (context, state) {
      final loggedIn = _auth.isLoggedIn;
      final loggingIn = state.matchedLocation == '/login';

      // Экраны, требующие авторизации.
      // /create-car СПЕЦИАЛЬНО не в списке: гость должен заполнить форму,
      // а подтверждение номера по SMS запрашивается только в момент
      // «Опубликовать» (см. _publish в create_car_screen). «Ленивый» вход.
      final protected = state.matchedLocation.startsWith('/profile') ||
          state.matchedLocation.startsWith('/my-cars') ||
          state.matchedLocation.startsWith('/wallet') ||
          state.matchedLocation.startsWith('/edit-car') ||
          state.matchedLocation.startsWith('/duplicate-car') ||
          state.matchedLocation.startsWith('/moderation') ||
          state.matchedLocation.startsWith('/chat') ||
          state.matchedLocation.startsWith('/favorites') ||
          state.matchedLocation.startsWith('/notifications');

      // Гость на защищённом экране → на логин
      if (!loggedIn && protected) return '/login';

      // Уже вошёл и открыл /login → на каталог
      if (loggedIn && loggingIn) return '/catalog';

      return null; // без редиректа
    },
  );
}

// Мост между Supabase authStateChanges и go_router refreshListenable.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(AuthRepository auth) {
    // При любом изменении сессии уведомляем роутер о необходимости пересчёта
    auth.authStateChanges.listen((_) => notifyListeners());
  }
}

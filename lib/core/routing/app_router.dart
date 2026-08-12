// ============================================================
// AUTO.RS — Маршрутизация приложения (go_router).
// Реактивный редирект: неавторизованный на защищённые экраны
// перенаправляется на /login. Каталог доступен и гостю.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';
import '../../features/admin/screens/kyc_moderation_screen.dart';
import '../../features/admin/screens/moderation_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/catalog/screens/car_detail_screen.dart';
import '../../features/chat/screens/chat_room_screen.dart';
import '../../features/chat/screens/chats_list_screen.dart';
import '../../features/favorites/screens/favorites_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/bookings/screens/bookings_screen.dart';
import '../../features/catalog/screens/catalog_screen.dart';
import '../../features/listings/screens/create_car_screen.dart';
import '../../features/listings/screens/my_cars_screen.dart';
import '../../features/profile/screens/kyc_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../shared/screens/home_shell.dart';

class AppRouter {
  AppRouter._();

  static final _auth = AuthRepository();

  static final GoRouter router = GoRouter(
    initialLocation: '/catalog',
    // Роутер пересобирается при смене состояния авторизации
    refreshListenable: _AuthNotifier(_auth),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
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
      // Мои объявления (продавец) — требует авторизации
      GoRoute(
        path: '/my-cars',
        builder: (context, state) => const MyCarsScreen(),
      ),
      // Модерация — требует авторизации (доступ к данным закрыт RLS/RPC для не-админов)
      GoRoute(
        path: '/moderation',
        builder: (context, state) => const ModerationScreen(),
      ),
      // Верификация KYC — требует авторизации
      GoRoute(
        path: '/kyc',
        builder: (context, state) => const KycScreen(),
      ),
      // KYC-модерация (админ) — требует авторизации; данные закрыты RLS/RPC
      GoRoute(
        path: '/kyc-moderation',
        builder: (context, state) => const KycModerationScreen(),
      ),
      // Уведомления — требует авторизации
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
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
            path: '/bookings',
            builder: (context, state) => const BookingsScreen(),
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

      // Экраны, требующие авторизации
      final protected = state.matchedLocation.startsWith('/profile') ||
          state.matchedLocation.startsWith('/bookings') ||
          state.matchedLocation.startsWith('/create-car') ||
          state.matchedLocation.startsWith('/my-cars') ||
          state.matchedLocation.startsWith('/moderation') ||
          state.matchedLocation.startsWith('/kyc') ||
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

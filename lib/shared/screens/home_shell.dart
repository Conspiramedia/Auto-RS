// ============================================================
// AUTO.RS — Каркас приложения с нижней навигацией.
// 5 вкладок: Каталог / Избранное / Диалоги / Брони / Профиль (ShellRoute).
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});

  // Текущий экран вкладки (подставляет go_router)
  final Widget child;

  // Индекс активной вкладки по текущему маршруту
  int _indexFor(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/favorites')) return 1;
    if (loc.startsWith('/chats')) return 2;
    if (loc.startsWith('/bookings')) return 3;
    if (loc.startsWith('/profile')) return 4;
    return 0; // /catalog
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/catalog');
        break;
      case 1:
        context.go('/favorites');
        break;
      case 2:
        context.go('/chats');
        break;
      case 3:
        context.go('/bookings');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = _indexFor(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => _onTap(context, i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'Каталог',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Избранное',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Диалоги',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Брони',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}

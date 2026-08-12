// ============================================================
// AUTO.RS — Каркас приложения с нижней навигацией.
// Оборачивает вкладки Каталог / Профиль (ShellRoute go_router).
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
    if (loc.startsWith('/profile')) return 1;
    return 0; // /catalog
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/catalog');
        break;
      case 1:
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
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}

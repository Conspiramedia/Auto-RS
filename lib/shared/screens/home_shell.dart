// ============================================================
// AUTO.RS — Каркас приложения с нижней навигацией.
// 5 пунктов в один ряд, «+» (создать объявление) — по центру:
//   Каталог / Избранное / + / Сообщения / Профиль
// «Брони» вынесены на экран каталога (кнопка рядом с «Фильтры»).
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});

  // Текущий экран вкладки (подставляет go_router)
  final Widget child;

  // Индекс активного пункта по маршруту. Слот 2 — «+» (создание,
  // отдельный экран /create-car вне shell) — не подсвечивается.
  int _indexFor(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/favorites')) return 1;
    if (loc.startsWith('/chats')) return 3;
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
        context.push('/create-car'); // «+» — создать объявление
        break;
      case 3:
        context.go('/chats');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = _indexFor(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(context, 0, index, Icons.directions_car_outlined,
                  Icons.directions_car, 'Каталог', theme),
              _navItem(context, 1, index, Icons.favorite_border,
                  Icons.favorite, 'Избранное', theme),
              // «+» по центру — без круга, крупнее (голый плюс визуально мельче
              // иконок с заливкой). Цвет — как у всех, из темы.
              _navItem(context, 2, index, Icons.add, Icons.add, 'Разместить',
                  theme, iconSize: 34),
              _navItem(context, 3, index, Icons.chat_bubble_outline,
                  Icons.chat_bubble, 'Сообщения', theme),
              _navItem(context, 4, index, Icons.person_outline, Icons.person,
                  'Профиль', theme),
            ],
          ),
        ),
      ),
    );
  }

  // Один пункт нижней панели: иконка + подпись, подсветка активного.
  // Иконка отрисована в блоке фиксированной высоты (34) и выровнена по низу,
  // чтобы подписи всех пунктов стояли на ОДНОМ уровне независимо от размера
  // значка (у «+» иконка крупнее).
  Widget _navItem(
    BuildContext context,
    int slot,
    int current,
    IconData icon,
    IconData activeIcon,
    String label,
    ThemeData theme, {
    double iconSize = 26,
  }) {
    final selected = slot == current;
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: () => _onTap(context, slot),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 34,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Icon(selected ? activeIcon : icon,
                    size: iconSize, color: color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

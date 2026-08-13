// ============================================================
// AUTO.RS — Каркас приложения с нижней навигацией.
// 5 пунктов в один ряд, «+» (создать объявление) — по центру:
//   Каталог / Избранное / + / Сообщения / Профиль
// «Брони» вынесены на экран каталога (кнопка рядом с «Фильтры»).
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Бренд-красный (акцент «Разместить»)
const Color _kRed = Color(0xFFE01E23);
// Тёмный фирменный (активный пункт меню)
const Color _kDark = Color(0xFF27272A);

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
              // Каталог — сетка карточек. Активная — залитые квадраты (window),
              // неактивная — контурная сетка.
              _navItem(context, 0, index, Icons.grid_view_outlined,
                  Icons.window, 'Каталог', theme),
              _navItem(context, 1, index, Icons.favorite_border,
                  Icons.favorite, 'Избранное', theme),
              // «+» по центру — бренд-красный, ЖИРНЫЙ (своя отрисовка, т.к.
              // стандартные Material Icons не поддерживают толщину).
              _navItem(context, 2, index, Icons.add, Icons.add, 'Разместить',
                  theme, iconSize: 34, iconColor: _kRed,
                  customIconBuilder: (color, size, filled) =>
                      _PlusIcon(color: color, size: size)),
              // Сообщения — спич-баббл.
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
  // iconColor — жёсткий цвет иконки (например, бренд-красный «+»); при null
  // цвет берётся из активности/темы, как у остальных пунктов.
  Widget _navItem(
    BuildContext context,
    int slot,
    int current,
    IconData icon,
    IconData activeIcon,
    String label,
    ThemeData theme, {
    double iconSize = 26,
    Color? iconColor,
    double? iconWeight,
    Widget Function(Color color, double size, bool filled)? customIconBuilder,
  }) {
    final selected = slot == current;
    // Активный пункт — фирменный тёмный (не синий theme.primary).
    final color = selected ? _kDark : theme.colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: () => _onTap(context, slot),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 36,
              child: Center(
                child: customIconBuilder != null
                    ? customIconBuilder(iconColor ?? color, iconSize, selected)
                    : Icon(selected ? activeIcon : icon,
                        size: iconSize, color: iconColor ?? color,
                        weight: iconWeight),
              ),
            ),
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

// Жирный плюс: две толстые линии (Material Icons не дают регулировать
// толщину, поэтому рисуем сами). Толщина ~18% от размера.
class _PlusIcon extends StatelessWidget {
  const _PlusIcon({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PlusPainter(color)),
    );
  }
}

class _PlusPainter extends CustomPainter {
  _PlusPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final paint = Paint()
      ..color = color
      ..strokeWidth = w * 0.18 // толщина линий
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final c = w / 2;
    final pad = w * 0.16; // отступ концов от краёв
    canvas.drawLine(Offset(pad, c), Offset(w - pad, c), paint);     // горизонт.
    canvas.drawLine(Offset(c, pad), Offset(c, w - pad), paint);     // вертик.
  }

  @override
  bool shouldRepaint(_PlusPainter old) => old.color != color;
}

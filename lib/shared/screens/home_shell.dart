// ============================================================
// AUTO.RS — Каркас приложения с нижней навигацией.
// 5 пунктов в один ряд, «+» (создать объявление) — по центру:
//   Каталог / Избранное / + / Сообщения / Профиль
// «Брони» вынесены на экран каталога (кнопка рядом с «Фильтры»).
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/notification_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/notifications_repository.dart';

// Бренд-красный (бейдж непрочитанных на «Сообщениях»)
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
              // «+» по центру — чёрный плюс в чёрной окружности (2px),
              // своя отрисовка: Material Icons не дают контроля толщины.
              _navItem(context, 2, index, Icons.add, Icons.add, 'Разместить',
                  theme, iconSize: 34, iconColor: Colors.black,
                  customIconBuilder: (color, size, filled) =>
                      _PlusIcon(color: color, size: size)),
              // Сообщения — спич-баббл + бейдж непрочитанных (Realtime).
              _navItem(context, 3, index, Icons.chat_bubble_outline,
                  Icons.chat_bubble, 'Сообщения', theme,
                  customIconBuilder: (color, size, filled) => _MessagesIcon(
                        icon: filled
                            ? Icons.chat_bubble
                            : Icons.chat_bubble_outline,
                        color: color,
                        size: size,
                      )),
              // Профиль — иконка + бейдж непрочитанных (не-чат) уведомлений,
              // виден на любой странице (нижнее меню всегда на экране).
              _navItem(context, 4, index, Icons.person_outline, Icons.person,
                  'Профиль', theme,
                  customIconBuilder: (color, size, filled) => _ProfileIcon(
                        icon: filled ? Icons.person : Icons.person_outline,
                        color: color,
                        size: size,
                      )),
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
  // iconColor — жёсткий цвет иконки (например, зелёный «+»); при null
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
    final c = w / 2;

    // Окружность-обводка: строго 2 логических пикселя, независимо от размера
    // иконки. Радиус уменьшаем на половину толщины, чтобы штрих (он рисуется
    // по центру линии) не выходил за границы виджета и не обрезался.
    const ring = 2.0;
    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = ring
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(c, c), c - ring / 2, ringPaint);

    // Сам «+» внутри круга: линии той же толщины, длина — 44% диаметра,
    // чтобы концы не упирались в обводку.
    final plusPaint = Paint()
      ..color = color
      ..strokeWidth = ring
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final arm = w * 0.22; // половина длины перекладины
    canvas.drawLine(Offset(c - arm, c), Offset(c + arm, c), plusPaint); // гориз.
    canvas.drawLine(Offset(c, c - arm), Offset(c, c + arm), plusPaint); // верт.
  }

  @override
  bool shouldRepaint(_PlusPainter old) => old.color != color;
}

// Иконка «Сообщения» с живым бейджем непрочитанных чат-уведомлений.
// Бейдж — красный кружок с белой цифрой (99+ при переполнении), показывается
// только залогиненному и только если непрочитанные есть. Саму иконку не меняем.
class _MessagesIcon extends StatefulWidget {
  const _MessagesIcon({
    required this.icon,
    required this.color,
    required this.size,
  });
  final IconData icon;
  final Color color;
  final double size;

  @override
  State<_MessagesIcon> createState() => _MessagesIconState();
}

class _MessagesIconState extends State<_MessagesIcon> {
  final _auth = AuthRepository();
  final _repo = NotificationsRepository();
  Stream<List<NotificationModel>>? _stream;

  @override
  void initState() {
    super.initState();
    // Стрим только для залогиненного (гостю уведомления не приходят).
    if (_auth.currentUser != null) _stream = _repo.stream();
  }

  @override
  Widget build(BuildContext context) {
    final iconWidget =
        Icon(widget.icon, size: widget.size, color: widget.color);
    if (_stream == null) return iconWidget;

    return StreamBuilder<List<NotificationModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        // Считаем непрочитанные сообщения чата.
        final unread = (snapshot.data ?? [])
            .where((n) =>
                !n.isRead && n.type == NotificationModel.typeChatMessage)
            .length;
        if (unread == 0) return iconWidget;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            iconWidget,
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: _kRed,
                  shape: BoxShape.circle,
                ),
                constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Иконка «Профиль» с бейджем непрочитанных НЕ-чат уведомлений (модерация и
// прочее). Чат-уведомления сюда не считаем — они на «Сообщениях». Стрим тот
// же, живой. Бейдж на нижнем меню виден на любой странице.
class _ProfileIcon extends StatefulWidget {
  const _ProfileIcon({
    required this.icon,
    required this.color,
    required this.size,
  });
  final IconData icon;
  final Color color;
  final double size;

  @override
  State<_ProfileIcon> createState() => _ProfileIconState();
}

class _ProfileIconState extends State<_ProfileIcon> {
  final _auth = AuthRepository();
  final _repo = NotificationsRepository();
  Stream<List<NotificationModel>>? _stream;

  @override
  void initState() {
    super.initState();
    if (_auth.currentUser != null) _stream = _repo.stream();
  }

  @override
  Widget build(BuildContext context) {
    final iconWidget =
        Icon(widget.icon, size: widget.size, color: widget.color);
    if (_stream == null) return iconWidget;

    return StreamBuilder<List<NotificationModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        // Непрочитанные, кроме чатовых (они на вкладке «Сообщения»).
        final unread = (snapshot.data ?? [])
            .where((n) =>
                !n.isRead && n.type != NotificationModel.typeChatMessage)
            .length;
        if (unread == 0) return iconWidget;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            iconWidget,
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: _kRed,
                  shape: BoxShape.circle,
                ),
                constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

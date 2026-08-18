// ============================================================
// AUTO.RS — Каркас приложения с нижней навигацией.
// 5 пунктов в один ряд, «+» (создать объявление) — по центру:
//   Каталог / Избранное / + / Сообщения / Профиль
// «Брони» вынесены на экран каталога (кнопка рядом с «Фильтры»).
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_brand.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/notifications_repository.dart';

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
    final t = context.t;

    return Scaffold(
      backgroundColor: AppBrandColors.bg,
      body: child,
      // Панель навигации: белая с верхней границей neutral10 — тот же
      // приём, что у шапки сайта (border-b border-neutral-10). Тени нет:
      // границы достаточно, чтобы отделить панель от контента.
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppBrandColors.bg,
          border: Border(
            top: BorderSide(color: AppBrandColors.neutral10),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Каталог — сетка карточек. Активная — залитые квадраты
                // (window), неактивная — контурная сетка.
                _navItem(context, 0, index, Icons.grid_view_outlined,
                    Icons.window, t.navCatalog, theme),
                _navItem(context, 1, index, Icons.favorite_border,
                    Icons.favorite, t.navFavorites, theme),
                // «+» по центру — ГЛАВНОЕ действие площадки. Приподнят над
                // рядом и залит зелёным: размещение объявления должно быть
                // заметно сразу, а не читаться как пятый равный пункт меню.
                _navItem(context, 2, index, Icons.add, Icons.add, t.navCreate,
                    theme,
                    iconSize: 34,
                    customIconBuilder: (color, size, filled) =>
                        const _CreateCta()),
                // Сообщения — спич-баббл + бейдж непрочитанных (Realtime).
                _navItem(context, 3, index, Icons.chat_bubble_outline,
                    Icons.chat_bubble, t.navMessages, theme,
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
                    t.navProfile, theme,
                    customIconBuilder: (color, size, filled) => _ProfileIcon(
                          icon: filled ? Icons.person : Icons.person_outline,
                          color: color,
                          size: size,
                        )),
              ],
            ),
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
    // Активный пункт — брендовый primary, неактивные — neutral60. Так же
    // на сайте различаются активная и обычная ссылка навигации.
    final color =
        selected ? AppBrandColors.primary : AppBrandColors.neutral60;
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
            // Подпись активного пункта — semibold: подсветка держится не
            // только на цвете. Заодно это работает там, где цвета плохо
            // различимы (яркий свет, ч/б режим доступности).
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppBrandText.caption.copyWith(
                color: color,
                fontWeight:
                    selected ? AppBrandFont.semibold : AppBrandFont.regular,
              ),
            ),
            // Индикатор активного пункта: короткая полоска под подписью.
            // Место под неё зарезервировано всегда (прозрачная у неактивных),
            // иначе подписи прыгали бы по вертикали при переключении.
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(
                width: 16,
                height: 2,
                decoration: BoxDecoration(
                  color: selected ? AppBrandColors.primary : Colors.transparent,
                  borderRadius: AppBrandRadius.pillAll,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CTA «Разместить» — приподнятая зелёная кнопка в центре меню.
//
// Подъём делаем через Transform.translate, а НЕ увеличением высоты панели:
// панель фиксированной высоты (64), и растягивать её ради одного пункта
// значило бы отнять место у контента на всех экранах. Кнопка выходит за
// границы своего слота вверх — Stack в _navItem обрезки не делает.
// ============================================================
class _CreateCta extends StatelessWidget {
  const _CreateCta();

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -8),
      child: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          // Зелёный главного действия — тот же, что у «Опубликовать»
          // и «Позвонить»: у пользователя одна ассоциация на весь продукт.
          color: AppBrandColors.green,
          shape: BoxShape.circle,
          // Тень dropdown из бренда: отделяет кнопку от панели и усиливает
          // ощущение подъёма — без неё зелёный круг читается плоским пятном.
          boxShadow: AppBrandElevation.dropdown,
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
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
  final _chats = ChatRepository();

  // Подписка на движение в сообщениях: по каждому событию перезапрашиваем
  // счётчик у сервера.
  StreamSubscription<void>? _sub;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    // Только для залогиненного: гостю сообщения не приходят.
    if (_auth.currentUser == null) return;

    _refresh();
    _sub = _chats.unreadSignals().listen((_) => _refresh());
  }

  // Счётчик считает сервер (get_unread_count): он учитывает участие в чате
  // и исключает отправителей, которых пользователь заблокировал. Повторить
  // эту логику на клиенте нельзя — данных о блокировках в потоке нет.
  Future<void> _refresh() async {
    try {
      final value = await _chats.totalUnread();
      if (!mounted) return;
      if (value != _unread) setState(() => _unread = value);
    } catch (_) {
      // Бейдж не критичен: при сбое сети оставляем прежнее значение,
      // следующее событие потока повторит попытку.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconWidget =
        Icon(widget.icon, size: widget.size, color: widget.color);
    if (_unread == 0) return iconWidget;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        Positioned(right: -6, top: -4, child: _CountBadge(count: _unread)),
      ],
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
            Positioned(right: -6, top: -4, child: _CountBadge(count: unread)),
          ],
        );
      },
    );
  }
}

// Красный бейдж-счётчик непрочитанных на иконке меню (99+ при переполнении).
// Один виджет на «Сообщения» и «Профиль»: бейджи выглядят одинаково, и
// разъехаться при правке они не должны.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: AppBrandColors.red,
        shape: BoxShape.circle,
      ),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        // Мельче ступени small: бейдж должен уместиться в кружок 16px,
        // не перекрывая иконку. Единственное место, где шкала не подходит.
        style: AppBrandText.small.copyWith(
          color: Colors.white,
          fontSize: 10,
          height: 1.1,
          fontWeight: AppBrandFont.bold,
        ),
      ),
    );
  }
}

// ============================================================
// AUTO.RS — Колокольчик уведомлений с живым бейджем непрочитанных.
//
// Считает НЕПРОЧИТАННЫЕ уведомления, КРОМЕ чатовых (чаты висят на вкладке
// «Сообщения», тут не дублируем). Пока есть непрочитанные:
//   • иконка красная и ПЕРИОДИЧЕСКИ покачивается («звонит»);
//   • в углу — красный бейдж с числом.
// Прочитал (markAllRead в /notifications) → стрим обновится, колокольчик
// замирает и становится обычным.
//
// Тап открывает экран уведомлений. Тот же класс с showBell:false и своей
// иконкой используется как бейдж на вкладке «Профиль» в нижнем меню.
// ============================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_brand.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/notifications_repository.dart';

// Считает непрочитанные не-чат уведомления из списка.
int unreadNonChat(List<NotificationModel> items) => items
    .where((n) => !n.isRead && n.type != NotificationModel.typeChatMessage)
    .length;

class NotifBell extends StatefulWidget {
  const NotifBell({
    super.key,
    required this.onTap,
    this.icon = Icons.notifications_none,
    this.activeIcon = Icons.notifications,
    this.size = 26,
    this.color,
    this.animate = true, // покачивать при непрочитанных
  });

  final VoidCallback onTap;
  final IconData icon;        // когда непрочитанных нет
  final IconData activeIcon;  // когда есть непрочитанные
  final double size;
  final Color? color;         // базовый цвет (если непрочитанных нет)
  final bool animate;

  @override
  State<NotifBell> createState() => _NotifBellState();
}

class _NotifBellState extends State<NotifBell>
    with SingleTickerProviderStateMixin {
  final _auth = AuthRepository();
  final _repo = NotificationsRepository();
  Stream<List<NotificationModel>>? _stream;

  late final AnimationController _ctrl;
  // Периодический «звонок»: качаем ~1.2с, пауза, повтор — пока есть непрочит.
  Timer? _ringTimer;
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (_auth.currentUser != null) _stream = _repo.stream();
  }

  @override
  void dispose() {
    _ringTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  // Управление периодическим покачиванием по флагу непрочитанных.
  void _syncRinging(bool hasUnread) {
    if (hasUnread == _hasUnread) return;
    _hasUnread = hasUnread;
    _ringTimer?.cancel();
    if (hasUnread && widget.animate) {
      // Звоним сразу, затем каждые ~3.2с (1.2с звон + ~2с пауза).
      _ctrl.forward(from: 0);
      _ringTimer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
        if (mounted) _ctrl.forward(from: 0);
      });
    } else {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Колокольчик в покое — тёмная плашка бренда; при непрочитанных
    // становится красным (сигнал важнее нейтральности).
    final baseColor = widget.color ?? AppBrandColors.dark;

    Widget bell(int unread) {
      final hasUnread = unread > 0;
      final iconColor = hasUnread ? AppBrandColors.red : baseColor;
      final icon = Icon(
        hasUnread ? widget.activeIcon : widget.icon,
        size: widget.size,
        color: iconColor,
      );

      // Покачивание вокруг верхней точки (как язычок колокольчика).
      final animated = AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          // Затухающая синусоида: несколько качков с уменьшением амплитуды.
          final t = _ctrl.value;
          final angle = t == 0
              ? 0.0
              : 0.35 * (1 - t) * math.sin(t * 2 * math.pi * 3);
          return Transform.rotate(
            angle: angle,
            alignment: Alignment.topCenter,
            child: child,
          );
        },
        child: icon,
      );

      if (!hasUnread) return icon;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          animated,
          Positioned(
            right: -6,
            top: -4,
            child: _Badge(count: unread),
          ),
        ],
      );
    }

    final content = _stream == null
        ? bell(0)
        : StreamBuilder<List<NotificationModel>>(
            stream: _stream,
            builder: (context, snapshot) {
              final unread = unreadNonChat(snapshot.data ?? []);
              // Запускаем/останавливаем покачивание после кадра.
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _syncRinging(unread > 0));
              return bell(unread);
            },
          );

    return InkWell(
      onTap: widget.onTap,
      customBorder: const CircleBorder(),
      child: Padding(padding: const EdgeInsets.all(8), child: content),
    );
  }
}

// Красный кружок-бейдж с числом (99+ при переполнении).
class _Badge extends StatelessWidget {
  const _Badge({required this.count});
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
        // Мельче ступени small: цифра должна уместиться в кружок 16px.
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

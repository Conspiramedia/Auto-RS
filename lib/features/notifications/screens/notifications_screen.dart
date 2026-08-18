// ============================================================
// AUTO.RS — Экран уведомлений. Realtime-лента (stream) + роутинг по тапу:
//   chat_message → чат-комната (action_id = chat_id).
// Прочие типы (устаревшие booking/kyc из старых записей) просто помечаются
// прочитанными без перехода. Тап помечает уведомление прочитанным.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_brand.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/repositories/notifications_repository.dart';
import '../../../shared/widgets/pill_back_button.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repo = NotificationsRepository();
  late final Stream<List<NotificationModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _repo.stream();
  }

  // Пометить прочитанным и перейти по типу
  Future<void> _onTap(NotificationModel n) async {
    // Помечаем прочитанным (не блокируем переход)
    _repo.markRead(n.id);

    // Переходы по тапу: чат — в комнату; модерация объявления — в карточку.
    // Устаревшие типы (booking/kyc) просто закрываются как прочитанные.
    if (n.actionId != null) {
      if (n.type == NotificationModel.typeChatMessage) {
        context.push('/chat/${n.actionId}');
      } else if (n.type == NotificationModel.typeCarRejected ||
          n.type == NotificationModel.typeCarApproved) {
        context.push('/car/${n.actionId}');
      }
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case NotificationModel.typeChatMessage:
        return Icons.chat_bubble;
      case NotificationModel.typeBookingStatus:
        return Icons.event_note;
      case NotificationModel.typeCarRejected:
        return Icons.cancel;
      case NotificationModel.typeCarApproved:
        return Icons.check_circle;
      case 'kyc_status_changed':
        return Icons.verified_user;
      default:
        return Icons.notifications;
    }
  }

  // «17 августа, 14:30» — названия месяцев берём из словаря: пакет intl
  // не содержит русской локали, DateFormat с 'ru' падает в рантайме.
  // [[intl-no-russian-locale]]
  String _formatDate(BuildContext context, DateTime date) {
    final months = context.t.monthNames;
    final month = months[(date.month - 1).clamp(0, 11)];
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '${date.day} $month, $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppBrandColors.bg,
      appBar: AppBar(
        leading: const PillBackButton(),
        title: Text(
          context.t.notificationsTitle,
          style: AppBrandText.h3.copyWith(color: AppBrandColors.neutral100),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all,
                color: AppBrandColors.neutral60),
            tooltip: context.t.notificationsReadAll,
            onPressed: () => _repo.markAllRead(),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: AppBrandColors.neutral30,
                    ),
                    const SizedBox(height: AppBrandSpacing.md),
                    Text(
                      context.t.notificationsEmpty,
                      textAlign: TextAlign.center,
                      style: AppBrandText.body
                          .copyWith(color: AppBrandColors.neutral60),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final n = items[i];
              return Container(
                // Непрочитанное — подложка surfaceSubtle: она отделяет новое
                // от прочитанного, но не спорит с текстом, как заливка
                // цветом. Прочитанное лежит на белом.
                color: n.isRead ? null : AppBrandColors.surfaceSubtle,
                child: ListTile(
                  onTap: () => _onTap(n),
                  leading: Icon(
                    _iconFor(n.type),
                    color: AppBrandColors.neutral60,
                  ),
                  title: Text(
                    n.title,
                    style: AppBrandText.body.copyWith(
                      color: AppBrandColors.neutral100,
                      // Непрочитанное выделено ещё и начертанием: подложка
                      // одна не работает при ч/б режиме доступности.
                      fontWeight: n.isRead
                          ? AppBrandFont.regular
                          : AppBrandFont.semibold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (n.body != null)
                        Text(
                          n.body!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppBrandText.caption
                              .copyWith(color: AppBrandColors.neutral60),
                        ),
                      const SizedBox(height: AppBrandSpacing.xs),
                      Text(
                        _formatDate(context, n.createdAt),
                        style: AppBrandText.caption
                            .copyWith(color: AppBrandColors.neutral60),
                      ),
                    ],
                  ),
                  trailing: n.isRead
                      ? null
                      : const Icon(
                          Icons.circle,
                          size: 10,
                          color: AppBrandColors.primary,
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

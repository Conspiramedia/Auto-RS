// ============================================================
// AUTO.RS — Экран уведомлений. Realtime-лента (stream) + роутинг по тапу:
//   chat_message → чат-комната (action_id = chat_id).
// Прочие типы (устаревшие booking/kyc из старых записей) просто помечаются
// прочитанными без перехода. Тап помечает уведомление прочитанным.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

    // Переход есть только для сообщений чата. Устаревшие типы (booking/kyc)
    // из старых записей просто закрываются как прочитанные.
    if (n.type == NotificationModel.typeChatMessage && n.actionId != null) {
      context.push('/chat/${n.actionId}');
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case NotificationModel.typeChatMessage:
        return Icons.chat_bubble;
      case NotificationModel.typeBookingStatus:
        return Icons.event_note;
      case 'kyc_status_changed':
        return Icons.verified_user;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const PillBackButton(), 
        title: const Text('Уведомления'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Прочитать все',
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
            return const Center(child: Text('Уведомлений пока нет'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final n = items[i];
              return Container(
                // Непрочитанные — лёгкий фон
                color: n.isRead
                    ? null
                    : Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.06),
                child: ListTile(
                  onTap: () => _onTap(n),
                  leading: Icon(_iconFor(n.type)),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight:
                          n.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: n.body != null
                      ? Text(n.body!,
                          maxLines: 2, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: n.isRead
                      ? null
                      : const Icon(Icons.circle, size: 10, color: Colors.blue),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

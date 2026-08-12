// ============================================================
// AUTO.RS — Custom Widget для FlutterFlow: ChatMessagesList
// ============================================================
// Realtime-лента сообщений чата с ГАРАНТИРОВАННЫМ авто-скроллом вниз
// как на свои, так и на входящие сообщения (Способ 2 из плана).
// Подписывается на поток messages по chat_id и после каждого обновления
// плавно докручивает список к последнему сообщению.
//
// -----------------------------------------------------------------
// НАСТРОЙКА ВО FLUTTERFLOW (Custom Widget):
//   Имя: ChatMessagesList
//   Parameters:
//     chatId        : String
//     currentUserId : String   (передать currentUser.uid)
//   Ширину/высоту задаёт FlutterFlow.
//
// Зависимость: supabase_flutter (уже в проекте).
// -----------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMessagesList extends StatefulWidget {
  const ChatMessagesList({
    super.key,
    this.width,
    this.height,
    required this.chatId,
    required this.currentUserId,
  });

  final double? width;
  final double? height;
  final String chatId;
  final String currentUserId;

  @override
  State<ChatMessagesList> createState() => _ChatMessagesListState();
}

class _ChatMessagesListState extends State<ChatMessagesList> {
  final ScrollController _scrollController = ScrollController();
  late final Stream<List<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    // Realtime-поток сообщений чата в хронологическом порядке.
    // Опирается на репликацию messages (миграция 0016) и RLS: поток отдаст
    // только сообщения чата, где текущий пользователь — участник.
    _stream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', widget.chatId)
        .order('created_at');
  }

  // Плавный скролл к последнему сообщению после отрисовки кадра
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final surfaceVariant = Theme.of(context).colorScheme.surfaceContainerHighest;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data!;

          // После каждого обновления списка (свои + входящие) — скролл вниз
          _scrollToBottom();

          if (messages.isEmpty) {
            return const Center(child: Text('Сообщений пока нет'));
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isMine = msg['sender_id'] == widget.currentUserId;
              final text = msg['text'] as String? ?? '';
              final isRead = msg['is_read'] as bool? ?? false;

              // Пузырь: мой — справа основным цветом, чужой — слева серым
              return Align(
                alignment:
                    isMine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: isMine ? primary : surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          color: isMine ? onPrimary : onSurface,
                        ),
                      ),
                      // Индикатор прочтения показываем только на СВОИХ сообщениях
                      if (isMine)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            isRead ? '✓✓' : '✓',
                            style: TextStyle(
                              fontSize: 11,
                              color: onPrimary.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                    ],
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

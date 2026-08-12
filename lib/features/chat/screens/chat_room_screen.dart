// ============================================================
// AUTO.RS — Экран чат-комнаты. Realtime-лента сообщений (виджет
// ChatMessagesList) + поле ввода + отправка. При входе помечает
// входящие прочитанными.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../widgets/chat_messages_list.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.chatId,
    this.peerName,
  });

  final String chatId;
  final String? peerName;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _repo = ChatRepository();
  final _auth = AuthRepository();
  final _inputCtrl = TextEditingController();

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // При открытии чата помечаем входящие сообщения прочитанными
    _repo.markRead(widget.chatId);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await _repo.sendMessage(chatId: widget.chatId, text: text);
      _inputCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось отправить: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(widget.peerName ?? 'Диалог')),
      body: Column(
        children: [
          // Realtime-лента сообщений (виджет с авто-скроллом)
          Expanded(
            child: ChatMessagesList(
              chatId: widget.chatId,
              currentUserId: userId,
            ),
          ),

          // Поле ввода + отправка
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Сообщение…',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

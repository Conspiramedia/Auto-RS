// ============================================================
// AUTO.RS — Экран чат-комнаты. Realtime-лента сообщений (виджет
// ChatMessagesList) + поле ввода + отправка. При входе помечает
// входящие прочитанными.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../widgets/chat_messages_list.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/widgets/pill_back_button.dart';

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
  // Показывать ли ряд быстрых шаблонов. Скрывается после первой отправки.
  bool _showTemplates = true;

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
      // Шаблоны прячем после первого отправленного сообщения: они нужны,
      // чтобы начать разговор, а дальше только занимают место над клавиатурой.
      if (mounted && _showTemplates) setState(() => _showTemplates = false);
    } catch (e) {
      if (mounted) {
        showAppSnack(context, 'Не удалось отправить: ${humanizeError(e)}');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Тап по шаблону подставляет текст в поле, а НЕ отправляет сразу:
  // человек должен успеть дописать деталь («Ещё актуально? Готов сегодня»)
  // и не отправить случайное сообщение незнакомому продавцу.
  void _applyTemplate(String text) {
    _inputCtrl
      ..text = text
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.id ?? '';
    final t = context.t;

    return Scaffold(
      appBar: AppBar(
        leading: const PillBackButton(),
        title: Text(widget.peerName ?? t.chatsTitle),
      ),
      body: Column(
        children: [
          // Realtime-лента сообщений (виджет с авто-скроллом)
          Expanded(
            child: ChatMessagesList(
              chatId: widget.chatId,
              currentUserId: userId,
            ),
          ),

          // Быстрые шаблоны: помогают начать разговор, когда не знаешь,
          // с чего. Список локальный (context.t), на сервер не ходит.
          if (_showTemplates)
            _QuickTemplates(
              templates: t.chatTemplateList,
              onPick: _applyTemplate,
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
                      decoration: InputDecoration(
                        hintText: t.chatMessageHint,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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

// ============================================================
// Ряд быстрых шаблонов над полем ввода.
//
// Горизонтальная прокрутка вместо переноса строк: шаблоны не должны
// съедать половину экрана — лента сообщений важнее.
// ============================================================
class _QuickTemplates extends StatelessWidget {
  const _QuickTemplates({required this.templates, required this.onPick});

  final List<String> templates;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: templates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final text = templates[i];
          return Center(
            child: ActionChip(
              label: Text(text),
              onPressed: () => onPick(text),
              labelStyle: theme.textTheme.bodySmall,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }
}

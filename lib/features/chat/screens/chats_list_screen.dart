// ============================================================
// AUTO.RS — Экран списка диалогов (My Chats). Список чатов с данными
// собеседника, машины и счётчиком непрочитанных. Тап → чат-комната.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/chat_with_details_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../shared/widgets/pill_back_button.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final _repo = ChatRepository();
  final _auth = AuthRepository();

  late Future<List<ChatWithDetailsModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchMyChatsDetailed();
  }

  void _reload() => setState(() => _future = _repo.fetchMyChatsDetailed());

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return Scaffold(
        appBar: AppBar(leading: const PillBackButton(), title: const Text('Диалоги')),
        body: const Center(child: Text('Войдите, чтобы видеть диалоги')),
      );
    }

    return Scaffold(
      appBar: AppBar(leading: const PillBackButton(), title: const Text('Диалоги')),
      body: FutureBuilder<List<ChatWithDetailsModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final chats = snapshot.data ?? [];
          if (chats.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text('Диалогов пока нет.\n'
                        'Напишите продавцу со страницы объявления.'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, i) => _ChatTile(
                chat: chats[i],
                onTap: () async {
                  final c = chats[i];
                  await context.push(
                    '/chat/${c.id}',
                    extra: c.opponentName ?? '${c.brand} ${c.model}',
                  );
                  // Вернулись из чата — обновим счётчики непрочитанных
                  _reload();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// Карточка диалога
class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.onTap});
  final ChatWithDetailsModel chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundImage:
            chat.opponentAvatar != null ? NetworkImage(chat.opponentAvatar!) : null,
        child: chat.opponentAvatar == null ? const Icon(Icons.person) : null,
      ),
      title: Text(chat.opponentName ?? 'Пользователь'),
      subtitle: Text('${chat.brand} ${chat.model}'),
      trailing: chat.unreadCount > 0
          ? CircleAvatar(
              radius: 12,
              backgroundColor: Colors.red,
              child: Text(
                '${chat.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            )
          : null,
    );
  }
}

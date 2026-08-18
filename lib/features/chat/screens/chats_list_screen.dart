// ============================================================
// AUTO.RS — Экран списка диалогов (Сообщения).
//
// Строка диалога: аватар собеседника, имя, превью последнего сообщения,
// умное время (14:24 / Вчера / Пн / 5 июн), бейдж непрочитанных,
// метки закреплён/заблокирован и подпись объявления.
//
// Свайп по строке (flutter_slidable, миграция 0041):
//   вправо — зелёная кнопка «Закрепить»/«Открепить» (чат прилипает к верху
//            списка; настройка личная, собеседник её не видит);
//   влево  — красная «Заблокировать» (с подтверждением) либо
//            «Разблокировать». Заблокированный не может писать: запрет
//            на уровне RLS-политики INSERT messages, а не только в UI.
//
// При первом открытии первые две строки один раз мягко качаются, подсказывая
// пользователю, что строку можно двигать пальцем.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../data/models/chat_with_details_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/widgets/app_button_colors.dart';
import '../../../shared/widgets/app_search_header.dart';
import '../../../shared/widgets/local_search_field.dart';
import '../../../shared/widgets/pill_back_button.dart';

// Ключ одноразового обучения свайпам (SharedPreferences).
const String _kSwipeTeachKey = 'chat_swipe_teach_shown';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final _repo = ChatRepository();
  final _auth = AuthRepository();

  late Future<List<ChatWithDetailsModel>> _future;

  // Локальный поиск по диалогам (общая шапка).
  String _query = '';

  // Нужно ли показать обучающее покачивание строк (один раз на установку).
  bool _teachSwipe = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchMyChatsDetailed();
    _loadTeachFlag();
  }

  // Читаем флаг обучения и СРАЗУ помечаем показанным: покачивание
  // одноразовое на установку приложения.
  Future<void> _loadTeachFlag() async {
    final sp = await SharedPreferences.getInstance();
    final shown = sp.getBool(_kSwipeTeachKey) ?? false;
    if (shown) return;
    await sp.setBool(_kSwipeTeachKey, true);
    if (mounted) setState(() => _teachSwipe = true);
  }

  // Фильтр диалогов по имени собеседника / марке-модели авто / превью.
  List<ChatWithDetailsModel> _filter(List<ChatWithDetailsModel> chats) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return chats;
    return chats.where((c) {
      final hay = '${c.opponentName ?? ''} ${c.brand} ${c.model} '
              '${c.lastMessage ?? ''}'
          .toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  void _reload() {
    setState(() {
      _future = _repo.fetchMyChatsDetailed();
    });
  }

  // ----------------------------------------------------------
  // Закрепить / открепить диалог (личная настройка пользователя).
  // ----------------------------------------------------------
  Future<void> _togglePin(ChatWithDetailsModel chat) async {
    final pin = !chat.pinned;
    try {
      await _repo.setChatPinned(chatId: chat.id, pinned: pin);
      if (!mounted) return;
      showAppSnack(context, pin ? context.t.chatPinned : context.t.chatUnpinned,
          success: true);
      _reload();
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'Не удалось изменить закрепление: ${humanizeError(e)}');
    }
  }

  // ----------------------------------------------------------
  // Заблокировать (с подтверждением) либо разблокировать собеседника.
  // ----------------------------------------------------------
  Future<void> _toggleBlock(ChatWithDetailsModel chat) async {
    final name = chat.opponentName ?? 'Пользователь';

    // Разблокировка — обратимое действие, выполняем сразу.
    if (chat.peerBlocked) {
      try {
        await _repo.unblockUser(chat.opponentId);
        if (!mounted) return;
        showAppSnack(context, '$name разблокирован', success: true);
        _reload();
      } catch (e) {
        if (!mounted) return;
        showAppSnack(context, 'Не удалось разблокировать: ${humanizeError(e)}');
      }
      return;
    }

    // Блокировка — сначала подтверждение.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(context.t.blockConfirmTitle(name)),
        content: Text(
          context.t.chatBlockConfirmBody,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              context.t.chatBlock,
              style: const TextStyle(
                color: AppButtonColors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _repo.blockUser(chat.opponentId);
      if (!mounted) return;
      showAppSnack(context, '$name заблокирован');
      _reload();
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'Не удалось заблокировать: ${humanizeError(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return Scaffold(
        appBar: AppBar(leading: const PillBackButton(), title: const Text('Диалоги')),
        body: const Center(child: Text('Войдите, чтобы видеть диалоги')),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppSearchHeader(),

            // Поиск по уже загруженным диалогам — локальный, на сервер
            // не ходит.
            LocalSearchField(
              value: _query,
              onChanged: (v) => setState(() => _query = v),
              hint: context.t.chatsSearchHint,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<ChatWithDetailsModel>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('${snapshot.error}'));
                  }
                  final all = snapshot.data ?? [];
                  final chats = _filter(all);

                  if (chats.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async => _reload(),
                      child: ListView(
                        children: [
                          const SizedBox(height: 100),
                          all.isEmpty
                              ? const _EmptyState()
                              : const _NoMatchState(),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: chats.length,
                      separatorBuilder: (_, __) => const Padding(
                        padding: EdgeInsets.only(left: 78),
                        child: Divider(height: 0.5),
                      ),
                      itemBuilder: (context, i) {
                        final chat = chats[i];
                        final tile = _SlidableChatTile(
                          chat: chat,
                          onTap: () async {
                            await context.push(
                              '/chat/${chat.id}',
                              extra: chat.opponentName ?? chat.carTitle,
                            );
                            _reload();
                          },
                          onPin: () => _togglePin(chat),
                          onBlock: () => _toggleBlock(chat),
                        );

                        // Первые две строки мягко качаются вправо-влево,
                        // подсказывая, что их можно двигать пальцем.
                        if (_teachSwipe && i < 2) {
                          return _TeachWiggle(
                            // Вторая строка стартует чуть позже — «волной».
                            delay: Duration(milliseconds: 700 + i * 350),
                            child: tile,
                          );
                        }
                        return tile;
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ОБУЧАЮЩЕЕ ПОКАЧИВАНИЕ СТРОКИ (одноразовая микро-анимация)
//
// Мягкий сдвиг вправо → пауза → влево → пружинный возврат на место.
// Играет один раз после [delay] с момента появления виджета.
// ============================================================

class _TeachWiggle extends StatefulWidget {
  const _TeachWiggle({required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  State<_TeachWiggle> createState() => _TeachWiggleState();
}

class _TeachWiggleState extends State<_TeachWiggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  // Траектория сдвига по X: вправо 32px (намёк на «Закрепить»), короткая
  // пауза, влево 24px (намёк на «Заблокировать»), возврат с лёгким
  // «отскоком». Амплитуда маленькая — панели действий не раскрываются.
  late final Animation<double> _dx = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 32.0)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 22,
    ),
    TweenSequenceItem(tween: ConstantTween(32.0), weight: 12),
    TweenSequenceItem(
      tween: Tween(begin: 32.0, end: -24.0)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 26,
    ),
    TweenSequenceItem(tween: ConstantTween(-24.0), weight: 12),
    TweenSequenceItem(
      tween: Tween(begin: -24.0, end: 0.0)
          .chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 28,
    ),
  ]).animate(_controller);

  @override
  void initState() {
    super.initState();
    // Небольшая задержка: пусть экран отрисуется, потом привлекаем взгляд.
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dx,
      builder: (context, child) => Transform.translate(
        offset: Offset(_dx.value, 0),
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ============================================================
// СТРОКА ДИАЛОГА СО СВАЙП-ДЕЙСТВИЯМИ (обёртка Slidable)
// ============================================================

class _SlidableChatTile extends StatelessWidget {
  const _SlidableChatTile({
    required this.chat,
    required this.onTap,
    required this.onPin,
    required this.onBlock,
  });

  final ChatWithDetailsModel chat;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(chat.id),
      // Свайп вправо (панель слева) — закрепление.
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.30,
        children: [
          SlidableAction(
            onPressed: (_) => onPin(),
            backgroundColor: AppButtonColors.green,
            foregroundColor: Colors.white,
            icon: chat.pinned ? Icons.push_pin_outlined : Icons.push_pin,
            label: chat.pinned ? 'Открепить' : 'Закрепить',
          ),
        ],
      ),
      // Свайп влево (панель справа) — блокировка.
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.34,
        children: [
          SlidableAction(
            onPressed: (_) => onBlock(),
            backgroundColor:
                chat.peerBlocked ? AppButtonColors.dark : AppButtonColors.red,
            foregroundColor: Colors.white,
            icon: chat.peerBlocked ? Icons.lock_open : Icons.block,
            label: chat.peerBlocked ? 'Разблокировать' : 'Заблокировать',
          ),
        ],
      ),
      child: _ChatTile(chat: chat, onTap: onTap),
    );
  }
}

// ============================================================
// СТРОКА ДИАЛОГА
// ============================================================

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.onTap});

  final ChatWithDetailsModel chat;
  final VoidCallback onTap;

  // Сокращения дней недели и месяцев (DateTime.weekday: 1=Пн … 7=Вс).
  // Задаём вручную: русские локальные данные intl в проекте не
  // инициализируются (нет flutter_localizations/initializeDateFormatting),
  // поэтому DateFormat('EEE', 'ru') упал бы в рантайме.
  static const List<String> _weekdaysRu = [
    'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс',
  ];
  static const List<String> _monthsRu = [
    'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];

  /// Время превью: «14:24» сегодня, «Вчера», «Пн», иначе «5 июн».
  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;

    if (diff == 0) return DateFormat('HH:mm').format(dt); // формат без локали
    if (diff == 1) return 'Вчера';
    if (diff < 7) return _weekdaysRu[dt.weekday - 1];     // Пн, Вт…
    return '${dt.day} ${_monthsRu[dt.month - 1]}';        // 5 июн
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasUnread = chat.hasUnread;

    // Превью: текст последнего сообщения, иначе подпись объявления.
    final preview = (chat.lastMessage?.trim().isNotEmpty ?? false)
        ? chat.lastMessage!.trim()
        : 'Сообщений пока нет';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _Avatar(chat: chat),
            const SizedBox(width: 12),

            // Имя + превью + подпись объявления
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.opponentName ?? 'Пользователь',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Метка заблокированного собеседника.
                      if (chat.peerBlocked) ...[
                        Icon(Icons.block,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                      ],
                      // Скрепка закреплённого чата.
                      if (chat.pinned) ...[
                        Icon(Icons.push_pin,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        _formatTime(chat.lastMessageAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread
                              ? AppButtonColors.red
                              : scheme.onSurfaceVariant,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            // Непрочитанное превью — темнее и жирнее.
                            color: hasUnread
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                      ),
                      // Бейдж непрочитанных.
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        _UnreadBadge(count: chat.unreadCount),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Подпись: по какому объявлению идёт диалог.
                  Text(
                    chat.carTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// АВАТАР СОБЕСЕДНИКА (фото или инициалы)
// ============================================================

class _Avatar extends StatelessWidget {
  const _Avatar({required this.chat});

  final ChatWithDetailsModel chat;

  static const double _size = 50;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = chat.opponentAvatar;

    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initials(scheme),
        ),
      );
    }
    return _initials(scheme);
  }

  Widget _initials(ColorScheme scheme) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        chat.opponentInitials,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

// ============================================================
// БЕЙДЖ НЕПРОЧИТАННЫХ
// ============================================================

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    // Больше 99 показываем как «99+».
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppButtonColors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ============================================================
// ПУСТОЕ СОСТОЯНИЕ (диалогов нет вообще)
// ============================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.forum_outlined, size: 56, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          const Text(
            'Диалогов пока нет',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Напишите продавцу со страницы объявления.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// НЕТ СОВПАДЕНИЙ ПО ПОИСКУ (диалоги есть, но фильтр пуст)
// ============================================================

class _NoMatchState extends StatelessWidget {
  const _NoMatchState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 52, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          const Text(
            'Ничего не найдено',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Попробуйте изменить запрос: имя собеседника, марка или модель.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

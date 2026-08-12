// ============================================================
// AUTO.RS — Кабинет броней. Две вкладки:
//   • Мои поездки (клиент): оплатить / отменить;
//   • Мой автопарк (владелец): подтвердить / отклонить / завершить.
// Смена статуса — серверными RPC (BookingsRepository), тексты ошибок
// (овербукинг, нет прав) показываются в SnackBar.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/enums/booking_status.dart';
import '../../../data/models/booking_with_car_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/bookings_repository.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final _repo = BookingsRepository();
  final _auth = AuthRepository();

  late Future<List<BookingWithCarModel>> _clientFuture;
  late Future<List<BookingWithCarModel>> _ownerFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final uid = _auth.currentUser?.id ?? '';
    setState(() {
      _clientFuture = _repo.fetchClientBookings(uid);
      _ownerFuture = _repo.fetchOwnerBookings(uid);
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Выполнить статусное действие и обновить списки
  Future<void> _runAction(Future<void> Function() action, String okMsg) async {
    try {
      await action();
      _snack(okMsg);
      _reload();
    } catch (e) {
      _snack(_humanError(e));
    }
  }

  String _humanError(Object e) {
    final s = e.toString();
    if (s.contains('заняты')) return 'Даты уже заняты другой подтверждённой бронью';
    if (s.contains('прав')) return 'Недостаточно прав для этого действия';
    return 'Ошибка: $s';
  }

  @override
  Widget build(BuildContext context) {
    // Гость — броней нет
    if (_auth.currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Мои брони')),
        body: const Center(child: Text('Войдите, чтобы видеть свои брони')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Мои брони'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Мои поездки'),
              Tab(text: 'Мой автопарк'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _BookingsList(
              future: _clientFuture,
              onReload: _reload,
              builder: _clientActions,
              emptyText: 'У вас пока нет броней',
            ),
            _BookingsList(
              future: _ownerFuture,
              onReload: _reload,
              builder: _ownerActions,
              emptyText: 'Нет заявок на ваши авто',
            ),
          ],
        ),
      ),
    );
  }

  // Кнопки для вкладки клиента
  List<Widget> _clientActions(BookingWithCarModel b) {
    return [
      if (b.status == BookingStatus.confirmed)
        FilledButton(
          onPressed: () => _runAction(
            () => _repo.payBooking(b.id).then((_) {}),
            'Бронь оплачена',
          ),
          child: const Text('Оплатить'),
        ),
      if (b.status == BookingStatus.pending ||
          b.status == BookingStatus.confirmed ||
          b.status == BookingStatus.paid)
        OutlinedButton(
          onPressed: () => _runAction(
            () => _repo.cancelBooking(b.id).then((_) {}),
            'Бронь отменена',
          ),
          child: const Text('Отменить'),
        ),
    ];
  }

  // Кнопки для вкладки владельца
  List<Widget> _ownerActions(BookingWithCarModel b) {
    return [
      if (b.status == BookingStatus.pending) ...[
        FilledButton(
          onPressed: () => _runAction(
            () => _repo.confirmBooking(b.id).then((_) {}),
            'Бронь подтверждена',
          ),
          child: const Text('Подтвердить'),
        ),
        OutlinedButton(
          onPressed: () => _runAction(
            () => _repo.rejectBooking(b.id).then((_) {}),
            'Заявка отклонена',
          ),
          child: const Text('Отклонить'),
        ),
      ],
      if (b.status == BookingStatus.paid)
        FilledButton(
          onPressed: () => _runAction(
            () => _repo.completeBooking(b.id).then((_) {}),
            'Аренда завершена',
          ),
          child: const Text('Завершить аренду'),
        ),
    ];
  }
}

// Список броней с pull-to-refresh
class _BookingsList extends StatelessWidget {
  const _BookingsList({
    required this.future,
    required this.onReload,
    required this.builder,
    required this.emptyText,
  });

  final Future<List<BookingWithCarModel>> future;
  final VoidCallback onReload;
  final List<Widget> Function(BookingWithCarModel) builder;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BookingWithCarModel>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return _RefreshableEmpty(text: emptyText, onReload: onReload);
        }
        return RefreshIndicator(
          onRefresh: () async => onReload(),
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) =>
                _BookingCard(booking: items[i], actions: builder(items[i])),
          ),
        );
      },
    );
  }
}

// Пустое состояние, поддерживающее pull-to-refresh
class _RefreshableEmpty extends StatelessWidget {
  const _RefreshableEmpty({required this.text, required this.onReload});
  final String text;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onReload(),
      child: ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(text)),
        ],
      ),
    );
  }
}

// Карточка одной брони
class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.actions});
  final BookingWithCarModel booking;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${booking.brand} ${booking.model}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StatusChip(status: booking.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_d(booking.startDate)} — ${_d(booking.endDate)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Итого: ${booking.totalPrice.toStringAsFixed(0)} '
              '${booking.currency.value}'
              '${booking.depositAmount > 0 ? ' + залог ${booking.depositAmount.toStringAsFixed(0)}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

// Цветной чип статуса брони
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BookingStatus.pending => ('Ожидает', Colors.orange),
      BookingStatus.confirmed => ('Подтверждена', Colors.blue),
      BookingStatus.paid => ('Оплачена', Colors.green),
      BookingStatus.rejected => ('Отклонена', Colors.red),
      BookingStatus.cancelled => ('Отменена', Colors.grey),
      BookingStatus.completed => ('Завершена', Colors.teal),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

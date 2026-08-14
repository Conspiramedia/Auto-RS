// ============================================================
// AUTO.RS — Экран профиля: данные, KYC-статус, баланс вендора,
// история транзакций, панель модерации (админ), выход.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/profile_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/transactions_repository.dart';
import '../../../shared/widgets/app_button_colors.dart';
import '../../../shared/widgets/dark_pill_button.dart';
import '../../../shared/widgets/pill_back_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthRepository();
  final _profileRepo = ProfileRepository();
  final _txRepo = TransactionsRepository();
  final _admin = AdminRepository();

  bool _loading = false;
  bool _isAdmin = false;

  late Future<_ProfileData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // Грузим профиль + баланс + транзакции + флаг админа
  Future<_ProfileData> _load() async {
    final profile = await _profileRepo.fetchMyProfile();
    final uid = _auth.currentUser?.id;

    double balance = 0;
    List<TransactionModel> txs = [];
    bool admin = false;
    if (uid != null) {
      balance = await _txRepo.getVendorBalance(uid);
      txs = await _txRepo.fetchMyTransactions();
      admin = await _admin.isAdmin();
    }
    _isAdmin = admin;
    return _ProfileData(profile: profile, balance: balance, transactions: txs);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _signOut() async {
    setState(() => _loading = true);
    try {
      await _auth.signOut();
      if (mounted) context.go('/catalog');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    // Гость
    if (user == null) {
      return Scaffold(
        appBar: AppBar(leading: const PillBackButton(), title: const Text('Профиль')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
              const SizedBox(height: 16),
              const Text('Гость'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('Войти'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(leading: const PillBackButton(), title: const Text('Профиль')),
      body: FutureBuilder<_ProfileData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Шапка
                Center(
                  child: Column(
                    children: [
                      const CircleAvatar(
                          radius: 40, child: Icon(Icons.person, size: 40)),
                      const SizedBox(height: 12),
                      Text(
                        data.profile?.fullName ?? user.email ?? '',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(user.email ?? '',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Баланс, «Мои объявления» (+ модерация админу) — доступны всем.
                ...[
                  // Баланс — самым верхом блока.
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.account_balance_wallet),
                      title: const Text('Баланс'),
                      trailing: Text(
                        '${data.balance.toStringAsFixed(2)} EUR',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Тёмная плашка-пилюля (как «Опубликовать»), по контенту, без иконки.
                  DarkPillButton(
                    label: 'Мои объявления',
                    variant: PillVariant.green,
                    onTap: () async {
                      await context.push('/my-cars');
                      _reload();
                    },
                  ),
                  // «Модерация объявлений» — только админу, сразу под «Мои
                  // объявления». Та же плашка-пилюля, синий вариант.
                  if (_isAdmin) ...[
                    const SizedBox(height: 12),
                    DarkPillButton(
                      label: 'Модерация объявлений',
                      variant: PillVariant.blue,
                      onTap: () => context.push('/moderation'),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],

                // История транзакций
                Text('История операций',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (data.transactions.isEmpty)
                  const Text('Операций пока нет')
                else
                  ...data.transactions.map((t) => _TxTile(tx: t)),

                const SizedBox(height: 24),
                // Единый вид со всеми плашками профиля: красный бренд-вариант,
                // белый текст. Во время выхода — неактивна («Выходим…»).
                DarkPillButton(
                  label: _loading ? 'Выходим…' : 'Выйти из аккаунта',
                  variant: PillVariant.red,
                  onTap: _loading ? null : _signOut,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileData {
  final ProfileModel? profile;
  final double balance;
  final List<TransactionModel> transactions;
  const _ProfileData({
    required this.profile,
    required this.balance,
    required this.transactions,
  });
}

// Строка транзакции
class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx});
  final TransactionModel tx;

  @override
  Widget build(BuildContext context) {
    // Знак и подпись по типу
    final (label, positive) = switch (tx.type) {
      TransactionModel.typePayment => ('Оплата', false),
      TransactionModel.typeRefund => ('Возврат', true),
      TransactionModel.typePenalty => ('Штраф', false),
      TransactionModel.typePayout => ('Выплата', true),
      _ => (tx.type, true),
    };
    final sign = positive ? '+' : '−';
    final color = positive ? Colors.green : Colors.red;

    return ListTile(
      dense: true,
      title: Text(label),
      subtitle: Text('${tx.status} · ${_d(tx.createdAt)}'),
      trailing: Text(
        '$sign${tx.amount.toStringAsFixed(2)} ${tx.currency}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

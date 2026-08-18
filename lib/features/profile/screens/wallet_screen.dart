// ============================================================
// AUTO.RS — Кошелёк: баланс и история операций.
//
// Баланс НЕ хранится отдельным полем — сервер считает его как сумму
// wallet_transactions (RPC get_balance). Поэтому цифра вверху и список
// внизу не могут разойтись по определению.
//
// ЭТАП 0: пополнение недоступно — платёжный провайдер не подключён.
// Единственный источник средств сейчас — подарок от администратора
// (credit_gift), а подарочное продвижение объявления пишется операцией на
// 0 EUR: услуга выдана, денег не двигалось.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../data/models/wallet_transaction_model.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../core/theme/app_brand.dart';
import '../../../shared/widgets/pill_back_button.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _repo = WalletRepository();

  late Future<_WalletData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // Баланс и историю запрашиваем параллельно — они независимы.
  Future<_WalletData> _load() async {
    final results = await Future.wait([
      _repo.getBalance(),
      _repo.fetchTransactions(),
    ]);
    return _WalletData(
      balance: results[0] as double,
      transactions: results[1] as List<WalletTransactionModel>,
    );
  }

  void _reload() {
    setState(() => _future = _load());
  }

  void _topUp() {
    final t = context.t;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.profileTopUp),
        content: Text(t.profileTopUpSoon),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.commonClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      appBar: AppBar(
        leading: const PillBackButton(),
        title: Text(t.profileBalance),
      ),
      body: FutureBuilder<_WalletData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      humanizeError(snapshot.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _reload,
                      child: Text(t.commonRetry),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _BalanceCard(balance: data.balance, onTopUp: _topUp),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    t.profileTransactions,
                    style: AppBrandText.h4
                        .copyWith(color: AppBrandColors.neutral100),
                  ),
                ),
                if (data.transactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 32),
                    child: Text(
                      t.profileTransactionsEmpty,
                      textAlign: TextAlign.center,
                      style: AppBrandText.body
                          .copyWith(color: AppBrandColors.neutral60),
                    ),
                  )
                else
                  for (final tx in data.transactions) _TransactionRow(tx: tx),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WalletData {
  const _WalletData({required this.balance, required this.transactions});
  final double balance;
  final List<WalletTransactionModel> transactions;
}

// ============================================================
// Карточка баланса
// ============================================================
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.onTopUp});

  final double balance;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        borderRadius: AppBrandRadius.cardAll,
        color: AppBrandColors.surfaceMuted,
      ),
      child: Column(
        children: [
          Text(
            t.profileBalance,
            style: AppBrandText.caption
                .copyWith(color: AppBrandColors.neutral60),
          ),
          const SizedBox(height: 6),
          Text(
            '${balance.toStringAsFixed(2)} EUR',
            style: AppBrandText.h2.copyWith(color: AppBrandColors.neutral100),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: onTopUp,
              style: FilledButton.styleFrom(
                backgroundColor: AppBrandColors.green,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppBrandRadius.controlAll,
                ),
              ),
              icon: const Icon(Icons.add, size: 20),
              // Пополнение появится с подключением провайдера — кнопку
              // оставляем видимой, но она честно говорит «скоро».
              label: Text(
                '${t.profileTopUp} · ${t.commonSoon}',
                style: AppBrandText.caption
                    .copyWith(fontWeight: AppBrandFont.semibold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Строка истории операций
// ============================================================
class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.tx});

  final WalletTransactionModel tx;

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    // Знак и цвет: начисления зелёные с плюсом, списания обычные с минусом.
    // Нулевые операции (подаренная услуга) — нейтральные, без знака: денег
    // не двигалось, и рисовать «+0.00» было бы враньём.
    final isZero = tx.amount == 0;
    final sign = isZero ? '' : (tx.isCredit ? '+' : '−');
    final amountColor = isZero
        ? AppBrandColors.neutral60
        // Зачисление — success, списание — error: знак операции читается
        // цветом, а не только минусом перед суммой.
        : (tx.isCredit ? AppBrandColors.success : AppBrandColors.error);

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: _iconBg(tx.type),
        child: Icon(_icon(tx.type), size: 18, color: Colors.white),
      ),
      title: Text(
        // Описание приходит с сервера уже человекочитаемым; если его нет,
        // показываем подпись типа операции из словаря.
        tx.description?.trim().isNotEmpty == true
            ? tx.description!
            : t.transactionType(tx.type),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppBrandText.body.copyWith(color: AppBrandColors.neutral100),
      ),
      subtitle: Text(
        '${t.transactionType(tx.type)} · ${_formatDate(tx.createdAt)}',
        style: AppBrandText.caption
            .copyWith(color: AppBrandColors.neutral60),
      ),
      trailing: Text(
        '$sign${tx.amount.abs().toStringAsFixed(2)} EUR',
        style: AppBrandText.body.copyWith(
          fontWeight: FontWeight.bold,
          color: amountColor,
        ),
      ),
    );
  }

  IconData _icon(String type) => switch (type) {
        WalletTransactionModel.typeTopup => Icons.add_card,
        WalletTransactionModel.typeBonus => Icons.star,
        WalletTransactionModel.typeGift => Icons.card_giftcard,
        WalletTransactionModel.typeSpend => Icons.shopping_cart_outlined,
        WalletTransactionModel.typeRefund => Icons.undo,
        _ => Icons.receipt_long,
      };

  Color _iconBg(String type) => switch (type) {
        WalletTransactionModel.typeSpend => AppBrandColors.neutral60,
        WalletTransactionModel.typeGift => AppBrandColors.gold,
        WalletTransactionModel.typeRefund => AppBrandColors.blue,
        _ => AppBrandColors.green,
      };

  // Дата вида «16.08.2026». Формат собираем вручную: пакет intl не содержит
  // русской локали, DateFormat с 'ru' падает в рантайме.
  // [[intl-no-russian-locale]]
  static String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d.$m.${date.year}';
  }
}

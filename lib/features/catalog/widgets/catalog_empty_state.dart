// ============================================================
// AUTO.RS — Пустое состояние каталога с действиями.
//
// Пустой экран без выхода — тупик: человек либо уходит, либо вслепую
// крутит фильтры. Поэтому даём два конкретных действия:
//   1) «Сообщить, когда появится» — подписка на текущие фильтры
//      (save_search_from_filters), главное действие;
//   2) «Сбросить фильтры» — если фильтры вообще заданы.
//
// Кнопка подписки показывается ТОЛЬКО когда фильтры непустые: сервер
// отклонит подписку «на всё» (это был бы спам), и предлагать заведомо
// падающее действие нельзя. Проверка — CarFilters.canSaveAsSearch.
//
// Подписка требует авторизации, поэтому гостя отправляем на вход и
// возвращаем обратно: сохранять «подписку без аккаунта» некуда, а терять
// намерение пользователя нельзя.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/saved_searches_repository.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/widgets/app_button_colors.dart';
import '../models/car_filters.dart';

class CatalogEmptyState extends StatefulWidget {
  const CatalogEmptyState({
    super.key,
    required this.filters,
    required this.query,
    required this.onResetFilters,
    required this.onRefresh,
  });

  // Текущие фильтры каталога — из них собирается подписка.
  final CarFilters filters;
  // Поисковая строка: попадает в подписку как марка, если фильтр марки пуст
  // (человек чаще всего вводит туда именно марку).
  final String query;
  final VoidCallback onResetFilters;
  final Future<void> Function() onRefresh;

  @override
  State<CatalogEmptyState> createState() => _CatalogEmptyStateState();
}

class _CatalogEmptyStateState extends State<CatalogEmptyState> {
  final _searches = SavedSearchesRepository();
  final _auth = AuthRepository();

  bool _saving = false;
  // Подписались в этой сессии — меняем кнопку на неактивную отметку, чтобы
  // человек не жал повторно (сервер дубль не создаст, но UI должен отвечать).
  bool _subscribed = false;

  // Фильтры для подписки: берём применённые, а поисковую строку используем
  // как марку, если марка явно не выбрана.
  Map<String, dynamic> _buildFilters() {
    final map = widget.filters.toSearchFilters();
    final q = widget.query.trim();
    if (q.isNotEmpty && !map.containsKey('brand')) {
      map['brand'] = q;
    }
    return map;
  }

  bool get _canSubscribe => _buildFilters().isNotEmpty;

  Future<void> _subscribe() async {
    if (_saving) return;

    final t = context.t;

    // Гость: отправляем на вход, после возврата действие можно повторить.
    if (_auth.currentUser == null) {
      await context.push('/login');
      if (!mounted) return;
      if (_auth.currentUser == null) return; // вход не состоялся
    }

    setState(() => _saving = true);
    try {
      await _searches.saveFromFilters(_buildFilters());
      if (!mounted) return;
      setState(() => _subscribed = true);
      showAppSnack(context, t.catalogNotifySaved, success: true);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final hasFilters = widget.filters.activeCount > 0 ||
        widget.query.trim().isNotEmpty;

    // ListView вместо Column: RefreshIndicator требует прокручиваемого
    // потомка, иначе жест «потянуть вниз» не сработает на пустом экране.
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            t.catalogEmptyTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            t.catalogEmptyBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          // Главное действие: подписка на текущий поиск.
          if (_canSubscribe)
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: (_saving || _subscribed) ? null : _subscribe,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_subscribed
                        ? Icons.check
                        : Icons.notifications_active_outlined),
                label: Text(
                  _subscribed ? t.catalogNotifySaved : t.catalogEmptyNotify,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // Второе действие: сброс фильтров — только если они заданы.
          if (hasFilters) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: widget.onResetFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: Text(t.catalogEmptyResetFilters),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppButtonColors.green,
                  side: const BorderSide(color: AppButtonColors.green),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

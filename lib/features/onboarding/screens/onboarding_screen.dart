// ============================================================
// AUTO.RS — Онбординг: три шага при первом запуске.
//
//   Шаг 1. Покупаю / Продаю  → определяет, что показать дальше;
//   Шаг 2. Город             → фильтр «рядом со мной»;
//   Шаг 3. Марки             → подписка save_search_from_filters.
//
// ПОСЛЕ третьего шага (не раньше) спрашиваем разрешение на уведомления:
// просить пуши до того, как человек увидел ценность, — верный способ
// получить отказ, который на iOS уже не переспросить.
//
// Продавцу шаги 2–3 не показываем: подписка на чужие объявления ему не
// нужна, он сразу уходит в создание объявления.
//
// ВСЕ строки — через словари (context.t), новых захардкоженных нет.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/reference_data.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/saved_searches_repository.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/widgets/app_button_colors.dart';
import '../onboarding_service.dart';
import '../widgets/push_permission_sheet.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _searches = SavedSearchesRepository();
  final _profiles = ProfileRepository();
  final _auth = AuthRepository();

  // Текущий шаг: 0 — цель, 1 — город, 2 — марки.
  int _step = 0;

  // Выбор пользователя.
  bool _isBuyer = true;
  String? _city;             // null = «Вся Сербия»
  final Set<String> _brands = {};

  bool _saving = false;

  // Всего шагов у покупателя три; продавцу показываем только первый.
  int get _totalSteps => _isBuyer ? 3 : 1;

  // ----------------------------------------------------------
  // Переходы между шагами
  // ----------------------------------------------------------

  void _next() {
    // Продавец: цель выбрана — онбординг закончен, подписки ему не нужны.
    if (!_isBuyer) {
      _finish(createSearch: false);
      return;
    }
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _finish(createSearch: true);
    }
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
  }

  // ----------------------------------------------------------
  // Завершение: сохраняем подписку, затем спрашиваем про пуши
  // ----------------------------------------------------------
  Future<void> _finish({required bool createSearch}) async {
    if (_saving) return;
    setState(() => _saving = true);

    final t = context.t;

    // Подписка на поиск. Создаём только покупателю и только если он задал
    // хоть один фильтр: сервер отклонит подписку «на всё» — и правильно
    // сделает, это был бы спам.
    //
    // Требует авторизации: у гостя аккаунта ещё нет. Гостю сохраняем выбор
    // локально — подписка создастся после входа (см. pendingFilters ниже).
    if (createSearch && (_city != null || _brands.isNotEmpty)) {
      final filters = <String, dynamic>{
        if (_city != null) 'city': _city,
        // Одна подписка = один набор фильтров, поэтому на каждую марку
        // заводим отдельную: иначе пришлось бы класть список в brand,
        // а предикат совпадения сравнивает одно значение.
      };

      try {
        if (_auth.currentUser != null) {
          if (_brands.isEmpty) {
            await _searches.saveFromFilters(filters);
          } else {
            for (final brand in _brands) {
              await _searches.saveFromFilters({...filters, 'brand': brand});
            }
          }
          // Роль в профиле: покупатель. Продавец выберет её при публикации.
          await _profiles.selectRole('customer');
        } else {
          // Гость: запоминаем выбор до входа.
          await OnboardingPrefs.savePending(city: _city, brands: _brands);
        }
      } catch (_) {
        // Подписка не сохранилась — онбординг всё равно завершаем: держать
        // человека на приветственном экране из-за фоновой операции нельзя.
      }
    }

    await OnboardingService.instance.markCompleted();
    if (!mounted) return;

    // Разрешение на уведомления — ПОСЛЕ третьего шага.
    if (createSearch) {
      await maybeAskPushPermission(context);
      if (!mounted) return;
      showAppSnack(context, t.onboardingSaved, success: true);
    }

    if (!mounted) return;
    // Покупатель идёт в каталог, продавец — сразу к созданию объявления.
    if (_isBuyer) {
      context.go('/catalog');
    } else {
      context.go('/catalog');
      context.push('/create-car');
    }
  }

  Future<void> _skip() async {
    await OnboardingService.instance.markCompleted();
    if (!mounted) return;
    context.go('/catalog');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        // Кнопка «назад» появляется со второго шага.
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _saving ? null : _back,
              )
            : null,
        automaticallyImplyLeading: false,
        title: Text(
          t.stepOf(_step + 1, _totalSteps),
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _skip,
            child: Text(t.commonSkip),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Индикатор прогресса: сразу видно, сколько осталось.
            LinearProgressIndicator(
              value: (_step + 1) / _totalSteps,
              minHeight: 3,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: AppButtonColors.green,
            ),
            Expanded(
              child: switch (_step) {
                0 => _GoalStep(
                    isBuyer: _isBuyer,
                    onChanged: (v) => setState(() => _isBuyer = v),
                  ),
                1 => _CityStep(
                    selected: _city,
                    onChanged: (v) => setState(() => _city = v),
                  ),
                _ => _BrandsStep(
                    selected: _brands,
                    onToggle: (brand) => setState(() {
                      if (!_brands.remove(brand)) _brands.add(brand);
                    }),
                  ),
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _next,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _step == _totalSteps - 1
                              ? t.onboardingFinish
                              : t.commonContinue,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ШАГ 1: Покупаю / Продаю
// ============================================================
class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.isBuyer, required this.onChanged});

  final bool isBuyer;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return _StepBody(
      title: t.onboardingGoalTitle,
      subtitle: t.onboardingGoalSubtitle,
      child: Column(
        children: [
          _ChoiceCard(
            icon: Icons.search,
            title: t.onboardingBuy,
            subtitle: t.onboardingBuyHint,
            selected: isBuyer,
            onTap: () => onChanged(true),
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            icon: Icons.sell_outlined,
            title: t.onboardingSell,
            subtitle: t.onboardingSellHint,
            selected: !isBuyer,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ШАГ 2: Город
// ============================================================
class _CityStep extends StatefulWidget {
  const _CityStep({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  State<_CityStep> createState() => _CityStepState();
}

class _CityStepState extends State<_CityStep> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    // Фильтрация по подстроке без учёта регистра и диакритики: в Сербии
    // город набирают и как «Nis», и как «Niš».
    final needle = _normalize(_query);
    final cities = ReferenceData.cities
        .where((c) => needle.isEmpty || _normalize(c).contains(needle))
        .toList();

    return _StepBody(
      title: t.onboardingCityTitle,
      subtitle: t.onboardingCitySubtitle,
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: t.onboardingCitySearch,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          // «Вся Сербия» — осмысленный вариант по умолчанию: город можно
          // не выбирать, подписка тогда охватит всю страну.
          _CityTile(
            label: t.onboardingCityAny,
            selected: widget.selected == null,
            onTap: () => widget.onChanged(null),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: cities.length,
              itemBuilder: (context, i) => _CityTile(
                label: cities[i],
                selected: widget.selected == cities[i],
                onTap: () => widget.onChanged(cities[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Упрощённая нормализация для поиска по списку: нижний регистр + снятие
  // сербской диакритики. Серверный f_normalize делает то же самое, но здесь
  // список локальный и обращаться на сервер незачем.
  static String _normalize(String s) {
    const map = {
      'č': 'c', 'ć': 'c', 'š': 's', 'ž': 'z', 'đ': 'd',
      'Č': 'c', 'Ć': 'c', 'Š': 's', 'Ž': 'z', 'Đ': 'd',
    };
    final lower = s.toLowerCase();
    final buffer = StringBuffer();
    for (final ch in lower.split('')) {
      buffer.write(map[ch] ?? ch);
    }
    return buffer.toString();
  }
}

class _CityTile extends StatelessWidget {
  const _CityTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppButtonColors.green)
          : const Icon(Icons.circle_outlined, color: Color(0xFFD4D4D8)),
      onTap: onTap,
    );
  }
}

// ============================================================
// ШАГ 3: Марки (множественный выбор)
// ============================================================
class _BrandsStep extends StatefulWidget {
  const _BrandsStep({required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  State<_BrandsStep> createState() => _BrandsStepState();
}

class _BrandsStepState extends State<_BrandsStep> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    final needle = _query.toLowerCase();
    final brands = ReferenceData.brands
        .where((b) => needle.isEmpty || b.toLowerCase().contains(needle))
        .toList();

    return _StepBody(
      title: t.onboardingBrandsTitle,
      subtitle: t.onboardingBrandsSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: t.onboardingBrandsHint,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final brand in brands)
                    FilterChip(
                      label: Text(brand),
                      selected: widget.selected.contains(brand),
                      onSelected: (_) => widget.onToggle(brand),
                      selectedColor: AppButtonColors.green.withValues(alpha: 0.15),
                      checkmarkColor: AppButtonColors.green,
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
// Общая обёртка шага: заголовок, подзаголовок, содержимое.
// ============================================================
class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// Крупная карточка выбора для первого шага.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppButtonColors.green : const Color(0xFFE4E4E7),
            width: selected ? 2 : 1,
          ),
          color: selected
              ? AppButtonColors.green.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 32,
                color: selected
                    ? AppButtonColors.green
                    : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppButtonColors.green),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Отложенный выбор гостя.
// ------------------------------------------------------------
// Гость проходит онбординг до создания аккаунта, поэтому подписку сохранить
// некуда. Запоминаем выбор локально и создаём подписки после первого входа
// (вызов applyPending — из экрана входа или каталога после авторизации).
// ============================================================
class OnboardingPrefs {
  OnboardingPrefs._();

  static const _keyCity = 'onboarding_pending_city';
  static const _keyBrands = 'onboarding_pending_brands';

  static Future<void> savePending({
    String? city,
    required Set<String> brands,
  }) async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (city != null) {
        await sp.setString(_keyCity, city);
      } else {
        await sp.remove(_keyCity);
      }
      await sp.setStringList(_keyBrands, brands.toList());
    } catch (_) {
      // Не сохранилось — пользователь подпишется вручную из каталога.
    }
  }

  // Создаёт отложенные подписки после входа и очищает сохранённый выбор.
  //
  // Возвращает true, ТОЛЬКО если подписки реально были созданы — вызывающий
  // по этому признаку решает, показывать ли снэкбар. Молчаливый вызов при
  // каждом старте приложения не должен ничего сообщать пользователю.
  //
  // Безопасно вызывать повторно и параллельно: без сохранённых данных сразу
  // выходит, а сохранённый выбор очищается только после успешного создания.
  static Future<bool> applyPending(SavedSearchesRepository repo) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final city = sp.getString(_keyCity);
      final brands = sp.getStringList(_keyBrands) ?? const [];

      if (city == null && brands.isEmpty) return false;

      final base = <String, dynamic>{if (city != null) 'city': city};
      if (brands.isEmpty) {
        await repo.saveFromFilters(base);
      } else {
        for (final brand in brands) {
          await repo.saveFromFilters({...base, 'brand': brand});
        }
      }

      // Чистим ТОЛЬКО после успеха: если создание упало на середине,
      // сохранённый выбор останется и попытка повторится при следующем
      // запуске. Дубли при этом не возникнут — сервер делает upsert по хэшу
      // фильтров, поэтому повторное создание той же подписки безвредно.
      await sp.remove(_keyCity);
      await sp.remove(_keyBrands);
      return true;
    } catch (_) {
      // Подписки не создались — попробуем при следующем входе.
      return false;
    }
  }

  // Есть ли отложенный выбор. Нужна, чтобы не дёргать сеть на старте
  // приложения, когда применять нечего (обычный случай).
  static Future<bool> hasPending() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getString(_keyCity) != null ||
          (sp.getStringList(_keyBrands) ?? const []).isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

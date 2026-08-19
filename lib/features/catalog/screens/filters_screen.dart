// ============================================================
// AUTO.RS — Экран фильтров каталога.
// Порядок: Город → Марка → Модель (появляется после выбора марки,
// модели грузятся из БД) → год/пробег/цена → кузов/КПП/топливо.
// Марка/город/модель — полноэкранный выбор со строкой поиска.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/config/reference_data.dart';
import '../../../data/repositories/cars_repository.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_brand.dart';
import '../../../shared/utils/number_formatters.dart';
import '../../../shared/widgets/app_button_colors.dart';
import '../../../shared/widgets/dark_pill_button.dart';
import '../models/car_filters.dart';
import '../../../shared/widgets/pill_back_button.dart';
import '../../../shared/widgets/app_close_button.dart';

/// Что экран фильтров отдаёт обратно каталогу: сами фильтры и строка
/// свободного поиска. Раньше поиск жил в шапке каталога отдельно от
/// фильтров; теперь он — поле этой формы, как на сайте, и возвращается
/// вместе с остальными условиями отбора.
class FiltersResult {
  const FiltersResult({required this.filters, required this.query});

  final CarFilters filters;
  final String query;
}

class FiltersScreen extends StatefulWidget {
  const FiltersScreen({
    super.key,
    required this.initial,
    this.initialQuery = '',
  });

  final CarFilters initial;

  /// Текущий поисковый запрос каталога — подставляется в поле поиска.
  final String initialQuery;

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  final _repo = CarsRepository();

  // Тип объявления: null (любой/«Все») | 'sale' | 'rent'.
  String? _listingType;

  String? _city;
  String? _brand;
  String? _model;
  String? _bodyType;
  String? _transmission;
  String? _fuel;

  // Марки из справочника (грузятся из БД при открытии экрана)
  List<String> _brands = [];

  // Модели выбранной марки (грузятся из БД)
  List<String> _models = [];
  bool _loadingModels = false;

  // Свободный поиск — первое поле формы (как на сайте).
  final _queryCtrl = TextEditingController();

  final _yearFromCtrl = TextEditingController();
  final _yearToCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  final _priceFromCtrl = TextEditingController();
  final _priceToCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _queryCtrl.text = widget.initialQuery;

    final f = widget.initial;
    _listingType = f.listingType;
    _city = f.city;
    _brand = f.brand;
    _model = f.model;
    _bodyType = f.bodyType;
    _transmission = f.transmission;
    _fuel = f.fuel;
    if (f.yearFrom != null) _yearFromCtrl.text = '${f.yearFrom}';
    if (f.yearTo != null) _yearToCtrl.text = '${f.yearTo}';
    if (f.mileageMax != null) _mileageCtrl.text = '${f.mileageMax}';
    if (f.priceFrom != null) _priceFromCtrl.text = '${f.priceFrom!.toInt()}';
    if (f.priceTo != null) _priceToCtrl.text = '${f.priceTo!.toInt()}';
    // Марки — из справочника; если марка уже выбрана — подгружаем её модели
    _loadBrands();
    if (_brand != null) _loadModels(_brand!);
  }

  // Загрузка марок из справочника (RPC get_car_brands)
  Future<void> _loadBrands() async {
    try {
      final brands = await _repo.fetchBrands();
      if (mounted) setState(() => _brands = brands);
    } catch (_) {
      // Фолбэк на статический список, если RPC недоступен
      if (mounted) setState(() => _brands = ReferenceData.brands);
    }
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _yearFromCtrl.dispose();
    _yearToCtrl.dispose();
    _mileageCtrl.dispose();
    _priceFromCtrl.dispose();
    _priceToCtrl.dispose();
    super.dispose();
  }

  // Загрузка моделей марки из БД
  Future<void> _loadModels(String brand) async {
    setState(() => _loadingModels = true);
    try {
      final models = await _repo.fetchModelsByBrand(brand);
      if (mounted) setState(() => _models = models);
    } catch (_) {
      if (mounted) setState(() => _models = []);
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  CarFilters _build() {
    // Разбор через parseFormatted*: в полях стоит ThousandsFormatter,
    // и «10 000» обычным int.tryParse не разобрался бы — фильтр цены
    // молча оказался бы пустым.
    int? pi(TextEditingController c) => parseFormattedInt(c.text);
    double? pd(TextEditingController c) => parseFormattedDouble(c.text);
    return CarFilters(
      listingType: _listingType,
      city: _city,
      brand: _brand,
      model: _model,
      yearFrom: pi(_yearFromCtrl),
      yearTo: pi(_yearToCtrl),
      mileageMax: pi(_mileageCtrl),
      priceFrom: pd(_priceFromCtrl),
      priceTo: pd(_priceToCtrl),
      bodyType: _bodyType,
      transmission: _transmission,
      fuel: _fuel,
    );
  }

  Future<void> _pickFromList({
    required String title,
    required List<String> options,
    required String? current,
    required ValueChanged<String?> onPicked,
  }) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _PickerScreen(
          title: title,
          options: options,
          current: current,
        ),
      ),
    );
    if (result != null) onPicked(result.isEmpty ? null : result);
  }

  // Тип объявления — СЕГМЕНТ из трёх кнопок, как на сайте
  // (FilterPanel.tsx): подложка surfaceActive, активная кнопка белая
  // с тенью sticky, неактивные — neutral55. Раньше здесь стояло
  // поле-пикер с нижним листом: на сайте тип выбирается в один тап,
  // а в приложении требовалось два, и вид поля не совпадал.
  Widget _listingTypeSegment() {
    // Пары (значение, подпись); null («Всё») кодируем пустой строкой.
    final segments = [
      ('', context.t.formAll),
      ('sale', context.t.filterSale),
      ('rent', context.t.filterRent),
    ];
    final current = _listingType ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Подпись НАД сегментом — на сайте это <label> над контролом.
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            context.t.formListingType,
            style:
                AppBrandText.caption.copyWith(color: AppBrandColors.neutral60),
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppBrandColors.surfaceActive,
            borderRadius: AppBrandRadius.controlAll,
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                for (final (i, (value, label)) in segments.indexed) ...[
                  // Зазор 4px между кнопками — gap-1 сегмента на сайте.
                  // Без него кнопки стояли вплотную, и активная плашка
                  // выглядела шире эталонной.
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: _segmentButton(
                      label: label,
                      selected: current == value,
                      onTap: () => setState(
                        () => _listingType = value.isEmpty ? null : value,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Одна кнопка сегмента. Активная — белая плашка с тенью sticky,
  // неактивная — прозрачная с текстом neutral55 (зеркало сайта).
  Widget _segmentButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    // Тень активной кнопки рисует ВНЕШНИЙ DecoratedBox, а не контейнер
    // внутри Material: изнутри она ложилась поверх белой заливки и
    // читалась как серая рамка, которой на сайте нет.
    return DecoratedBox(
      decoration: selected
          ? const BoxDecoration(
              borderRadius: AppBrandRadius.controlAll,
              boxShadow: AppBrandElevation.sticky,
            )
          : const BoxDecoration(),
      child: Material(
        color: selected ? AppBrandColors.bg : Colors.transparent,
        borderRadius: AppBrandRadius.controlAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppBrandRadius.controlAll,
          child: Container(
            height: 36,
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppBrandText.caption.copyWith(
                fontWeight: AppBrandFont.semibold,
                color: selected
                    ? AppBrandColors.neutral100
                    : AppBrandColors.neutral55,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // СОДЕРЖИМОЕ ШТОРКИ, а не отдельный экран. Открывается снизу поверх
    // каталога — так же, как панель фильтров на сайте (FilterPanel.tsx:
    // fixed inset-0 + items-end + rounded-t-card).
    return Padding(
      // Отступ снизу равен высоте клавиатуры: без него поля ввода
      // (поиск, цена, год, пробег) уезжали бы под неё.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        // Высота как max-h-[90vh] на сайте: над шторкой остаётся полоска
        // каталога, и видно, что слой модальный, а не новая страница.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ШАПКА ОДИН В ОДИН С САЙТОМ (FilterPanel.tsx): заголовок
            // слева, крестик справа, между ними распор. Кнопки «Сбросить»
            // здесь НЕТ — на сайте сброс живёт в ряду чипсов над выдачей
            // (FilterChips.tsx), и держать его ещё и в шапке значило бы
            // иметь два разных места для одного действия.
            //
            // Отступы p-4 и mb-4 сайта: 16 по краям и 16 под шапкой.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppBrandSpacing.md,
                AppBrandSpacing.md,
                AppBrandSpacing.md,
                AppBrandSpacing.md,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      context.t.catalogFilters,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // h4 = 18px/600 — размер text-lg font-semibold
                      // заголовка шторки на сайте. h3 (20px) был на 2px
                      // крупнее эталона.
                      style: AppBrandText.h4
                          .copyWith(color: AppBrandColors.neutral100),
                    ),
                  ),
                  AppCloseButton(
                    tooltip: context.t.commonClose,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ],
              ),
            ),

            // Поля прокручиваются внутри шторки; shrinkWrap нужен,
            // чтобы короткая форма не растягивала слой на все 90%.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                children: [
                  // ПОРЯДОК ПОЛЕЙ ПОВТОРЯЕТ САЙТ (components/FilterPanel.tsx):
                  // тип → поиск → марка+модель → город → цена+год → пробег →
                  // кузов+коробка+топливо. Раньше порядок был свой (поиск и тип
                  // переставлены, город перед маркой, цена после пробега), и два
                  // клиента одного каталога выглядели по-разному.

                  // 1) Тип объявления — сегмент, определяющий саму выдачу,
                  // поэтому стоит первым, а не сужает её по признаку.
                  _listingTypeSegment(),
                  const SizedBox(height: 12),

                  // 2) Поиск — единственное поле свободного ввода.
                  _labeledField(
                    label: context.t.filterSearch,
                    child: TextField(
                      controller: _queryCtrl,
                      textInputAction: TextInputAction.search,
                      style: AppBrandText.body
                          .copyWith(color: AppBrandColors.neutral100),
                      decoration: InputDecoration(
                        hintText: context.t.filterSearchHint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3) Марка и Модель — в один ряд, как grid-cols-2 на сайте.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _labeledField(
                          label: context.t.formBrand,
                          child: _pickerField(
                            value: _brand,
                            hint: context.t.formAny,
                            onTap: () => _pickFromList(
                              title: context.t.formBrand,
                              options: _brands.isNotEmpty
                                  ? _brands
                                  : ReferenceData.brands,
                              current: _brand,
                              onPicked: (v) {
                                setState(() {
                                  _brand = v;
                                  _model = null; // сброс модели при смене марки
                                  _models = [];
                                });
                                if (v != null) _loadModels(v);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        // Модель ВСЕГДА видна — на сайте поле не исчезает, а
                        // становится неактивным с подсказкой «Сначала выберите
                        // марку». Прежде поля просто не было, пока нет марки,
                        // и ряд разъезжался.
                        child: _labeledField(
                          label: context.t.formModel,
                          child: _pickerField(
                            value: _brand == null ? null : _model,
                            enabled: _brand != null &&
                                !_loadingModels &&
                                _models.isNotEmpty,
                            hint: _brand == null
                                ? context.t.pickerModelNoBrand
                                : _loadingModels
                                    ? context.t.formSearchHint
                                    : _models.isEmpty
                                        ? context.t.formNoModels
                                        : context.t.formAny,
                            onTap: () => _pickFromList(
                              title: context.t.formModel,
                              options: _models,
                              current: _model,
                              onPicked: (v) => setState(() => _model = v),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 4) Город — на всю ширину, как на сайте.
                  _labeledField(
                    label: context.t.formCity,
                    child: _pickerField(
                      value: _city,
                      hint: context.t.formAny,
                      onTap: () => _pickFromList(
                        title: context.t.formCity,
                        options: ReferenceData.cities,
                        current: _city,
                        onPicked: (v) => setState(() => _city = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 5) Цена и Год — два блока в ряд, внутри каждого «от/до».
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _rangeField(
                          label: context.t.formPrice,
                          from: _priceFromCtrl,
                          to: _priceToCtrl,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _rangeField(
                          label: context.t.carYear,
                          from: _yearFromCtrl,
                          to: _yearToCtrl,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 6) Пробег — на всю ширину.
                  _labeledField(
                    label: context.t.formMileage,
                    child: _numField(_mileageCtrl),
                  ),
                  const SizedBox(height: 12),

                  // 7) Кузов, Коробка, Топливо — три поля в ряд (grid-cols-3).
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _mapPickerField(
                          label: context.t.formBodyType,
                          value: _bodyType,
                          items: context.t.bodyTypes,
                          hint: context.t.formAny,
                          onPicked: (v) => setState(() => _bodyType = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _mapPickerField(
                          label: context.t.formTransmission,
                          value: _transmission,
                          items: context.t.transmissions,
                          hint: context.t.formAny,
                          onPicked: (v) => setState(() => _transmission = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _mapPickerField(
                          label: context.t.carFuel,
                          value: _fuel,
                          items: context.t.fuels,
                          hint: context.t.formAny,
                          onPicked: (v) => setState(() => _fuel = v),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  // Главное действие: зелёный CTA на всю ширину — так же
                  // выглядит «Показать результаты» на сайте. Кнопка
                  // прокручивается вместе с полями, как в форме сайта,
                  // а не приколота к низу слоя.
                  SafeArea(
                    top: false,
                    child: DarkPillButton(
                      label: context.t.filtersShowResults,
                      expand: true,
                      variant: PillVariant.green,
                      onTap: () => Navigator.pop(
                        context,
                        FiltersResult(
                          filters: _build(),
                          query: _queryCtrl.text.trim(),
                        ),
                      ),
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

  // ------------------------------------------------------------
  // ПОДПИСЬ НАД ПОЛЕМ — как <label> на сайте.
  // ------------------------------------------------------------
  // Раньше подписи врезались в рамку (floatingLabelBehavior.always),
  // и «Год выпуска от» читалось внутри контура, тогда как на сайте над
  // парой полей стоит один заголовок «Год выпуска». Обёртка выносит
  // подпись наружу и применяется ко ВСЕМ полям экрана разом.
  Widget _labeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                AppBrandText.caption.copyWith(color: AppBrandColors.neutral60),
          ),
        ),
        child,
      ],
    );
  }

  // Поле-пикер: выглядит как поле ввода, но открывает список выбора.
  // Подпись сюда больше не передаётся — её рисует _labeledField снаружи.
  // Рамка, радиус и фокус приходят из inputDecorationTheme (пакет А1) —
  // здесь они НЕ переопределяются, иначе поле разъедется с формой подачи.
  Widget _pickerField({
    required String? value,
    required VoidCallback onTap,
    bool enabled = true,
    String? hint,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: AppBrandRadius.controlAll,
      child: InputDecorator(
        decoration: InputDecoration(
          enabled: enabled,
          // isDense + плотные отступы дают компактную высоту панели
          // фильтров: на сайте это h-10 (40px) против h-11 в формах.
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value ?? (hint ?? context.t.formAny),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // Незаполненное значение — подсказка neutral30, как
                // hintStyle полей; выбранное — основной текст.
                style: AppBrandText.body.copyWith(
                  color: value == null
                      ? AppBrandColors.neutral30
                      : AppBrandColors.neutral100,
                ),
              ),
            ),
            if (enabled)
              const Icon(
                Icons.arrow_drop_down,
                color: AppBrandColors.neutral60,
              ),
          ],
        ),
      ),
    );
  }

  // Поле-пикер для справочника-Map (кузов/КПП/топливо). Использует ТОТ ЖЕ
  // _pickerField и полноэкранный выбор, что «Город»/«Марка», поэтому шрифт
  // значения «Все» гарантированно совпадает. Хранится ключ БД (items.key),
  // а пользователю показывается подпись (items.value).
  Widget _mapPickerField({
    required String label,
    required String? value,
    required Map<String, String> items,
    required ValueChanged<String?> onPicked,
    String? hint,
  }) {
    // Текущая подпись по сохранённому ключу (null → hint внутри _pickerField)
    final currentLabel = value == null ? null : items[value];

    return _labeledField(
      label: label,
      child: _pickerField(
        value: currentLabel,
        hint: hint,
        onTap: () => _pickFromList(
          title: label,
          options: items.values.toList(),
          current: currentLabel,
          onPicked: (picked) {
            // picked — подпись (или null для «Все»); возвращаем ключ БД
            if (picked == null) {
              onPicked(null);
              return;
            }
            final key = items.entries.firstWhere((e) => e.value == picked).key;
            onPicked(key);
          },
        ),
      ),
    );
  }

  // Числовое поле БЕЗ подписи: её рисует _labeledField снаружи.
  // Разряды разделяются пробелом тем же форматтером, что в форме
  // подачи: «10 000».
  Widget _numField(TextEditingController ctrl, {String? hint}) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: const [ThousandsFormatter()],
      style: AppBrandText.body.copyWith(color: AppBrandColors.neutral100),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  // Диапазон «от/до»: ОДНА подпись над парой полей, внутри полей —
  // плейсхолдеры «от» и «до». Ровно так устроены «Цена, €» и «Год
  // выпуска» на сайте; прежде подпись дублировалась в каждом поле
  // («Год выпуска от» / «Год выпуска до»).
  Widget _rangeField({
    required String label,
    required TextEditingController from,
    required TextEditingController to,
  }) {
    return _labeledField(
      label: label,
      child: Row(
        children: [
          Expanded(child: _numField(from, hint: context.t.formRangeFrom)),
          const SizedBox(width: 8),
          Expanded(child: _numField(to, hint: context.t.formRangeTo)),
        ],
      ),
    );
  }
}

// ============================================================
// Полноэкранный экран выбора из списка со строкой поиска.
// Возвращает выбранное значение, '' для «не важно» (сброс), null при отмене.
// ============================================================
class _PickerScreen extends StatefulWidget {
  const _PickerScreen({
    required this.title,
    required this.options,
    required this.current,
  });

  final String title;
  final List<String> options;
  final String? current;

  @override
  State<_PickerScreen> createState() => _PickerScreenState();
}

class _PickerScreenState extends State<_PickerScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.options
        : widget.options.where((o) => o.toLowerCase().contains(q)).toList();

    return Scaffold(
      appBar:
          AppBar(leading: const PillBackButton(), title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              style: AppBrandText.body,
              decoration: InputDecoration(
                hintText: context.t.formSearchHint,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  title: Text(context.t.formAny),
                  trailing: widget.current == null
                      ? const Icon(Icons.check, color: AppBrandColors.green)
                      : null,
                  onTap: () => Navigator.pop(context, ''),
                ),
                const Divider(height: 1),
                ...filtered.map(
                  (o) => ListTile(
                    title: Text(o),
                    trailing: widget.current == o
                        ? const Icon(Icons.check, color: AppBrandColors.green)
                        : null,
                    onTap: () => Navigator.pop(context, o),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

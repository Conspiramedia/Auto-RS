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
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/number_formatters.dart';
import '../../../shared/widgets/app_button_colors.dart';
import '../../../shared/widgets/dark_pill_button.dart';
import '../models/car_filters.dart';
import '../../../shared/widgets/pill_back_button.dart';

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

  // Подписи типа для пикера (ключ → текст пользователю). Метод, а не
  // константа: подписи зависят от языка и берутся из словаря.
  Map<String, String> _listingTypeLabels(BuildContext context) => {
        'sale': context.t.filterSale,
        'rent': context.t.filterRent,
      };
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

  void _reset() {
    setState(() {
      _listingType = null;
      _city = null;
      _brand = null;
      _model = null;
      _models = [];
      _bodyType = null;
      _transmission = null;
      _fuel = null;
      // Поиск сбрасывается вместе с фильтрами: он такое же условие
      // отбора, и «Сбросить» должно очищать выдачу целиком.
      _queryCtrl.clear();
      _yearFromCtrl.clear();
      _yearToCtrl.clear();
      _mileageCtrl.clear();
      _priceFromCtrl.clear();
      _priceToCtrl.clear();
    });
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

  // Выбор типа объявления из трёх вариантов (Все / Продажа / Аренда).
  // Всего 3 пункта — показываем компактным нижним листом без поиска.
  // Значение: null (Все) | 'sale' | 'rent'.
  Future<void> _pickListingType() async {
    // Пары (значение, подпись); null-значение кодируем пустой строкой.
    final options = [
      ('', context.t.formAll),
      ('sale', context.t.filterSale),
      ('rent', context.t.filterRent),
    ];
    final current = _listingType ?? '';

    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, label) in options)
              ListTile(
                title: Text(label),
                trailing: current == value
                    ? const Icon(Icons.check, color: AppBrandColors.green)
                    : null,
                onTap: () => Navigator.pop(ctx, value),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return; // закрыли лист без выбора
    setState(() => _listingType = picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppBrandColors.bg,
      appBar: AppBar(
        leading: const PillBackButton(),
        title: Text(
          context.t.catalogFilters,
          style: AppBrandText.h3.copyWith(color: AppBrandColors.neutral100),
        ),
        actions: [
          // Сброс — ghost-кнопка: деструктивное действие красным, но без
          // заливки, чтобы не спорить с зелёным CTA внизу экрана.
          TextButton(
            onPressed: _reset,
            style: TextButton.styleFrom(
              foregroundColor: AppBrandColors.red,
            ),
            child: Text(
              context.t.catalogFiltersReset,
              style: AppBrandText.caption
                  .copyWith(fontWeight: AppBrandFont.medium),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Свободный поиск — первое поле формы, как на сайте: это самый
          // частый способ отбора («Golf 7», «Beograd»), и прятать его за
          // остальными условиями незачем.
          TextField(
            controller: _queryCtrl,
            textInputAction: TextInputAction.search,
            style: AppBrandText.body
                .copyWith(color: AppBrandColors.neutral100),
            decoration: InputDecoration(
              labelText: context.t.filterSearch,
              hintText: context.t.filterSearchHint,
              prefixIcon: const Icon(
                Icons.search,
                color: AppBrandColors.neutral60,
              ),
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
          ),
          const SizedBox(height: 12),

          // 0) Тип объявления — поле-пикер (как «Город»). Выбор из трёх:
          // Все / Продажа / Аренда. null (Все) → сервер отдаёт оба типа.
          _pickerField(
            label: context.t.formListingType,
            value: _listingType == null ? null : _listingTypeLabels(context)[_listingType],
            hint: context.t.formAll,
            onTap: _pickListingType,
          ),
          const SizedBox(height: 12),

          // 1) Город
          _pickerField(
            label: context.t.formCity,
            value: _city,
            hint: context.t.formAny,
            onTap: () => _pickFromList(
              title: context.t.formCity,
              options: ReferenceData.cities,
              current: _city,
              onPicked: (v) => setState(() => _city = v),
            ),
          ),
          const SizedBox(height: 12),

          // 2) Марка
          _pickerField(
            label: context.t.formBrand,
            value: _brand,
            hint: context.t.formAny,
            onTap: () => _pickFromList(
              title: context.t.formBrand,
              options: _brands.isNotEmpty ? _brands : ReferenceData.brands,
              current: _brand,
              onPicked: (v) {
                setState(() {
                  _brand = v;
                  _model = null; // сбрасываем модель при смене марки
                  _models = [];
                });
                if (v != null) _loadModels(v);
              },
            ),
          ),

          // 3) Модель — появляется только когда выбрана марка
          if (_brand != null) ...[
            const SizedBox(height: 12),
            if (_loadingModels)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (_models.isEmpty)
              _pickerField(
                label: context.t.formModel,
                value: null,
                enabled: false,
                hint: context.t.formNoModels,
                onTap: () {},
              )
            else
              _pickerField(
                label: context.t.formModel,
                value: _model,
                hint: context.t.formAny,
                onTap: () => _pickFromList(
                  title: context.t.formModel,
                  options: _models,
                  current: _model,
                  onPicked: (v) => setState(() => _model = v),
                ),
              ),
          ],
          const SizedBox(height: 12),

          _rangeRow(context.t.carYear, _yearFromCtrl, _yearToCtrl,
              hintFrom: context.t.formAny, hintTo: context.t.formAny),
          const SizedBox(height: 12),
          _numField(_mileageCtrl, context.t.formMileage, hint: context.t.formAny),
          const SizedBox(height: 12),
          _rangeRow(context.t.formPrice, _priceFromCtrl, _priceToCtrl,
              hintFrom: context.t.formAny, hintTo: context.t.formAny),
          const SizedBox(height: 12),

          _mapPickerField(
            label: context.t.formBodyType,
            value: _bodyType,
            items: ReferenceData.bodyTypes,
            hint: context.t.formAny,
            onPicked: (v) => setState(() => _bodyType = v),
          ),
          const SizedBox(height: 12),
          _mapPickerField(
            label: context.t.formTransmission,
            value: _transmission,
            items: ReferenceData.transmissions,
            hint: context.t.formAny,
            onPicked: (v) => setState(() => _transmission = v),
          ),
          const SizedBox(height: 12),
          _mapPickerField(
            label: context.t.carFuel,
            value: _fuel,
            items: ReferenceData.fuels,
            hint: context.t.formAny,
            onPicked: (v) => setState(() => _fuel = v),
          ),

          const SizedBox(height: 24),
          // Главное действие экрана: зелёный CTA на всю ширину — так же
          // выглядит «Показать результаты» на сайте.
          DarkPillButton(
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
        ],
      ),
    );
  }

  // Поле-пикер: выглядит как поле ввода, но открывает список выбора.
  // Рамка, радиус и фокус приходят из inputDecorationTheme (пакет А1) —
  // здесь они НЕ переопределяются, иначе поле разъедется с формой подачи.
  Widget _pickerField({
    required String label,
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
          labelText: label,
          enabled: enabled,
        ),
        child: SizedBox(
          // Высота контрола из темы: поля и кнопки в одном столбце
          // обязаны совпадать по ритму.
          height: AppTheme.controlHeight - 24,
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
      ),
    );
  }

  // Поле-пикер для справочника-Map (кузов/КПП/топливо). Использует ТОТ ЖЕ
  // _pickerField и полноэкранный выбор, что «Город»/«Марка», поэтому шрифт
  // значения «Любой» гарантированно совпадает. Хранится ключ БД (items.key),
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

    return _pickerField(
      label: label,
      value: currentLabel,
      hint: hint,
      onTap: () => _pickFromList(
        title: label,
        options: items.values.toList(),
        current: currentLabel,
        onPicked: (picked) {
          // picked — подпись (или null для «Любой»); возвращаем ключ БД
          if (picked == null) {
            onPicked(null);
            return;
          }
          final key = items.entries
              .firstWhere((e) => e.value == picked)
              .key;
          onPicked(key);
        },
      ),
    );
  }

  // Числовое поле: лейбл в разрыве рамки (всегда), подсказка внутри.
  // Рамка/радиус/фокус — из темы (пакет А1). Разряды разделяются
  // пробелом тем же форматтером, что в форме подачи: «10 000».
  Widget _numField(TextEditingController ctrl, String label, {String? hint}) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: const [ThousandsFormatter()],
      style: AppBrandText.body.copyWith(color: AppBrandColors.neutral100),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
    );
  }

  // Диапазон «от/до»: два поля в ряд, у каждого лейбл в рамке — без
  // отдельного заголовка сверху, чтобы вид совпадал с остальными полями.
  // hintFrom/hintTo — серые подсказки-плейсхолдеры внутри каждого поля,
  // намекающие на границу диапазона («с любого» / «по любой»).
  Widget _rangeRow(
      String label, TextEditingController from, TextEditingController to,
      {String? hintFrom, String? hintTo}) {
    return Row(
      children: [
        Expanded(child: _numField(from, context.t.rangeFrom(label), hint: hintFrom)),
        const SizedBox(width: 12),
        Expanded(child: _numField(to, context.t.rangeTo(label), hint: hintTo)),
      ],
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
      appBar: AppBar(leading: const PillBackButton(), title: Text(widget.title)),
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

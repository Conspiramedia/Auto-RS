// ============================================================
// AUTO.RS — Экран фильтров каталога.
// Порядок: Город → Марка → Модель (появляется после выбора марки,
// модели грузятся из БД) → год/пробег/цена → кузов/КПП/топливо.
// Марка/город/модель — полноэкранный выбор со строкой поиска.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/config/reference_data.dart';
import '../../../data/repositories/cars_repository.dart';
import '../models/car_filters.dart';

class FiltersScreen extends StatefulWidget {
  const FiltersScreen({super.key, required this.initial});

  final CarFilters initial;

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  final _repo = CarsRepository();

  String? _city;
  String? _brand;
  String? _model;
  String? _bodyType;
  String? _transmission;
  String? _fuel;

  // Модели выбранной марки (грузятся из БД)
  List<String> _models = [];
  bool _loadingModels = false;

  final _yearFromCtrl = TextEditingController();
  final _yearToCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  final _priceFromCtrl = TextEditingController();
  final _priceToCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
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
    // Если марка уже выбрана — подгружаем её модели
    if (_brand != null) _loadModels(_brand!);
  }

  @override
  void dispose() {
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
    int? pi(TextEditingController c) => int.tryParse(c.text.trim());
    double? pd(TextEditingController c) =>
        double.tryParse(c.text.trim().replaceAll(',', '.'));
    return CarFilters(
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
      _city = null;
      _brand = null;
      _model = null;
      _models = [];
      _bodyType = null;
      _transmission = null;
      _fuel = null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Фильтры'),
        actions: [
          TextButton(onPressed: _reset, child: const Text('Сбросить')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1) Город — первым полем
          _pickerField(
            label: 'Город',
            value: _city,
            onTap: () => _pickFromList(
              title: 'Город',
              options: ReferenceData.cities,
              current: _city,
              onPicked: (v) => setState(() => _city = v),
            ),
          ),
          const SizedBox(height: 12),

          // 2) Марка
          _pickerField(
            label: 'Марка',
            value: _brand,
            onTap: () => _pickFromList(
              title: 'Марка',
              options: ReferenceData.brands,
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
                label: 'Модель',
                value: null,
                enabled: false,
                hint: 'Нет объявлений этой марки',
                onTap: () {},
              )
            else
              _pickerField(
                label: 'Модель',
                value: _model,
                onTap: () => _pickFromList(
                  title: 'Модель',
                  options: _models,
                  current: _model,
                  onPicked: (v) => setState(() => _model = v),
                ),
              ),
          ],
          const SizedBox(height: 12),

          _rangeRow('Год', _yearFromCtrl, _yearToCtrl),
          const SizedBox(height: 12),
          _numField(_mileageCtrl, 'Пробег до, км'),
          const SizedBox(height: 12),
          _rangeRow('Цена, EUR', _priceFromCtrl, _priceToCtrl),
          const SizedBox(height: 12),

          _dropdown(
            label: 'Тип кузова',
            value: _bodyType,
            items: ReferenceData.bodyTypes,
            onChanged: (v) => setState(() => _bodyType = v),
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: 'Коробка передач',
            value: _transmission,
            items: ReferenceData.transmissions,
            onChanged: (v) => setState(() => _transmission = v),
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: 'Топливо',
            value: _fuel,
            items: ReferenceData.fuels,
            onChanged: (v) => setState(() => _fuel = v),
          ),

          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context, _build()),
            child: const Text('Показать объявления'),
          ),
        ],
      ),
    );
  }

  Widget _pickerField({
    required String label,
    required String? value,
    required VoidCallback onTap,
    bool enabled = true,
    String? hint,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          enabled: enabled,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value ?? (hint ?? 'Любой'),
              style: TextStyle(color: value == null ? Colors.grey : null),
            ),
            if (enabled) const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Любой')),
        ...items.entries.map(
          (e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)),
        ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _numField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _rangeRow(
      String label, TextEditingController from, TextEditingController to) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: _numField(from, 'от')),
            const SizedBox(width: 12),
            Expanded(child: _numField(to, 'до')),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// Полноэкранный экран выбора из списка со строкой поиска.
// Возвращает выбранное значение, '' для «Любой», null при отмене.
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
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Поиск…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  title: const Text('Любой'),
                  trailing: widget.current == null
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () => Navigator.pop(context, ''),
                ),
                const Divider(height: 1),
                ...filtered.map(
                  (o) => ListTile(
                    title: Text(o),
                    trailing: widget.current == o
                        ? const Icon(Icons.check, color: Colors.blue)
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

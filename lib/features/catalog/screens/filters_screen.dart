// ============================================================
// AUTO.RS — Экран фильтров каталога. Dropdown марки/города + диапазоны
// год/пробег/цена + dropdown кузов/КПП/топливо. Возвращает CarFilters.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/config/reference_data.dart';
import '../models/car_filters.dart';

class FiltersScreen extends StatefulWidget {
  const FiltersScreen({super.key, required this.initial});

  final CarFilters initial;

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  String? _brand;
  String? _city;
  String? _bodyType;
  String? _transmission;
  String? _fuel;

  final _yearFromCtrl = TextEditingController();
  final _yearToCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  final _priceFromCtrl = TextEditingController();
  final _priceToCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Восстанавливаем ранее выбранные фильтры
    final f = widget.initial;
    _brand = f.brand;
    _city = f.city;
    _bodyType = f.bodyType;
    _transmission = f.transmission;
    _fuel = f.fuel;
    if (f.yearFrom != null) _yearFromCtrl.text = '${f.yearFrom}';
    if (f.yearTo != null) _yearToCtrl.text = '${f.yearTo}';
    if (f.mileageMax != null) _mileageCtrl.text = '${f.mileageMax}';
    if (f.priceFrom != null) _priceFromCtrl.text = '${f.priceFrom!.toInt()}';
    if (f.priceTo != null) _priceToCtrl.text = '${f.priceTo!.toInt()}';
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

  // Собрать CarFilters из текущих значений
  CarFilters _build() {
    int? pi(TextEditingController c) => int.tryParse(c.text.trim());
    double? pd(TextEditingController c) =>
        double.tryParse(c.text.trim().replaceAll(',', '.'));
    return CarFilters(
      brand: _brand,
      city: _city,
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
      _brand = null;
      _city = null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Фильтры'),
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text('Сбросить'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Марка (dropdown)
          _dropdown(
            label: 'Марка',
            value: _brand,
            items: {for (final b in ReferenceData.brands) b: b},
            onChanged: (v) => setState(() => _brand = v),
          ),
          const SizedBox(height: 12),
          // Город (dropdown)
          _dropdown(
            label: 'Город',
            value: _city,
            items: {for (final c in ReferenceData.cities) c: c},
            onChanged: (v) => setState(() => _city = v),
          ),
          const SizedBox(height: 12),

          // Год от-до
          _rangeRow('Год', _yearFromCtrl, _yearToCtrl),
          const SizedBox(height: 12),

          // Пробег до
          _numField(_mileageCtrl, 'Пробег до, км'),
          const SizedBox(height: 12),

          // Цена от-до
          _rangeRow('Цена, EUR', _priceFromCtrl, _priceToCtrl),
          const SizedBox(height: 12),

          // Кузов
          _dropdown(
            label: 'Тип кузова',
            value: _bodyType,
            items: ReferenceData.bodyTypes,
            onChanged: (v) => setState(() => _bodyType = v),
          ),
          const SizedBox(height: 12),
          // КПП
          _dropdown(
            label: 'Коробка передач',
            value: _transmission,
            items: ReferenceData.transmissions,
            onChanged: (v) => setState(() => _transmission = v),
          ),
          const SizedBox(height: 12),
          // Топливо
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

  // Dropdown с ключ→подпись; value — выбранный ключ (или null)
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

  // Числовое поле
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

  // Ряд «от — до»
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

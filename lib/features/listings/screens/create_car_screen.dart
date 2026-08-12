// ============================================================
// AUTO.RS — Экран «Подать объявление».
// Форма характеристик + загрузка фото в Storage + RPC create_car_v2.
// Объявление создаётся со статусом moderation (одобряет админ).
//
// Поля выбора (марка/модель/год/город/кузов/КПП/топливо) выполнены теми же
// пикерами, что и фильтры каталога, — единый стиль и размер шрифта.
// Марку/модель/город можно ВВЕСТИ ВРУЧНУЮ, если их нет в справочнике.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/reference_data.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/cars_repository.dart';
import '../utils/generate_temp_uuid.dart';
import '../utils/validate_car_form.dart';

class CreateCarScreen extends StatefulWidget {
  const CreateCarScreen({super.key});

  @override
  State<CreateCarScreen> createState() => _CreateCarScreenState();
}

class _CreateCarScreenState extends State<CreateCarScreen> {
  final _carsRepo = CarsRepository();
  final _auth = AuthRepository();
  final _picker = ImagePicker();

  // Временный UUID папки машины (для пути загрузки фото до создания объявления)
  final String _tempCarUuid = generateTempUuid();

  // Значения выбора (как в фильтрах — String?)
  String? _brand;
  String? _model;
  String? _year;
  String? _city;
  String? _bodyType;      // ключ enum body_type
  String? _transmission;  // ключ enum transmission_type
  String? _fuel;          // ключ enum fuel_type

  // Числовые поля свободного ввода
  final _mileageCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  // Описание (до 6000 символов)
  final _descCtrl = TextEditingController();

  // Максимум фото на одно объявление
  static const int _maxPhotos = 10;

  // Марки из справочника (грузятся из БД при открытии)
  List<String> _brands = [];
  // Модели выбранной марки
  List<String> _models = [];
  bool _loadingModels = false;

  // Тип объявления
  String _listingType = 'sale'; // 'sale' | 'rent' | 'both'

  // Загруженные публичные URL фото (по порядку)
  final List<String> _photoUrls = [];

  bool _uploading = false;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  @override
  void dispose() {
    _mileageCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // Марки из справочника (RPC get_car_brands), с фолбэком на статический список.
  Future<void> _loadBrands() async {
    try {
      final brands = await _carsRepo.fetchBrands();
      if (mounted) setState(() => _brands = brands);
    } catch (_) {
      if (mounted) setState(() => _brands = ReferenceData.brands);
    }
  }

  // Модели выбранной марки (RPC get_car_models).
  Future<void> _loadModels(String brand) async {
    setState(() => _loadingModels = true);
    try {
      final models = await _carsRepo.fetchModelsByBrand(brand);
      if (mounted) setState(() => _models = models);
    } catch (_) {
      if (mounted) setState(() => _models = []);
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Список годов: от текущего+1 до 1900 (свежие сверху)
  List<String> get _years {
    final now = DateTime.now().year + 1;
    return [for (int y = now; y >= 1900; y--) '$y'];
  }

  // Только цифры из строки (для пробега/цены — убираем пробелы-разделители).
  String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  // Открыть полноэкранный выбор (с опцией ручного ввода при allowCustom).
  Future<void> _pick({
    required String title,
    required List<String> options,
    required String? current,
    required ValueChanged<String?> onPicked,
    bool allowCustom = false,
  }) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _SelectScreen(
          title: title,
          options: options,
          current: current,
          allowCustom: allowCustom,
        ),
      ),
    );
    // null — отмена; '' быть не может (нет опции «Любой» при создании)
    if (result != null) onPicked(result);
  }

  // Выбор из справочника-Map (кузов/КПП/топливо): показываем подписи,
  // храним ключ enum. Необязательные — есть опция «Не указано».
  Future<void> _pickMap({
    required String title,
    required Map<String, String> items,
    required String? current,
    required ValueChanged<String?> onPicked,
  }) async {
    final currentLabel = current == null ? null : items[current];
    await _pick(
      title: title,
      options: ['— Не указано —', ...items.values],
      current: currentLabel,
      onPicked: (picked) {
        if (picked == null || picked == '— Не указано —') {
          onPicked(null);
          return;
        }
        final entry =
            items.entries.where((e) => e.value == picked).cast<MapEntry<String, String>?>();
        onPicked(entry.isEmpty ? null : entry.first!.key);
      },
    );
  }

  // Выбор фото из галереи и загрузка в Storage
  Future<void> _pickAndUpload() async {
    // Сколько ещё можно добавить до лимита
    final remaining = _maxPhotos - _photoUrls.length;
    if (remaining <= 0) {
      _snack('Можно добавить не более $_maxPhotos фото');
      return;
    }

    // Выбор СРАЗУ НЕСКОЛЬКИХ фото за один раз.
    final List<XFile> files = await _picker.pickMultiImage(
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (files.isEmpty) return;

    // Клиент мог выбрать больше лимита — берём только первые `remaining`.
    final selected = files.take(remaining).toList();
    if (files.length > remaining) {
      _snack('Добавлены первые $remaining из ${files.length} — лимит '
          '$_maxPhotos фото');
    }

    setState(() => _uploading = true);
    try {
      // Грузим по очереди; каждое добавляем сразу — прогресс виден.
      for (final file in selected) {
        final bytes = await file.readAsBytes();
        final url = await _carsRepo.uploadCarImage(
          tempCarUuid: _tempCarUuid,
          index: _photoUrls.length, // индекс = текущая длина (порядок сохранится)
          bytes: bytes,
        );
        if (!mounted) return;
        setState(() => _photoUrls.add(url));
      }
    } catch (e) {
      _snack('Не удалось загрузить часть фото: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // Публикация объявления
  Future<void> _publish() async {
    if (_auth.currentUser == null) {
      _snack('Войдите, чтобы подать объявление');
      return;
    }

    final year = int.tryParse(_year ?? '');
    // Из строки убираем пробелы-разделители тысяч (формат «1 000») перед парсингом.
    final priceDigits = _digitsOnly(_priceCtrl.text);
    final price = priceDigits.isEmpty ? null : double.tryParse(priceDigits);
    final mileage = int.tryParse(_digitsOnly(_mileageCtrl.text));

    // Валидация БЕЗ обязательной цены (цена опциональна → «Договорная»).
    final err = validateCarForm(
      _brand,
      _model,
      year,
      1, // фиктивная валидная цена: проверку цены делаем отдельно ниже
      _city,
      _photoUrls,
    );
    if (err != null) {
      _snack(err);
      return;
    }
    // Если цена введена, но некорректна (например, 0) — предупреждаем.
    if (priceDigits.isNotEmpty && (price == null || price <= 0)) {
      _snack('Цена должна быть больше нуля или оставьте поле пустым');
      return;
    }
    if (_uploading) {
      _snack('Дождитесь загрузки фото');
      return;
    }

    setState(() => _publishing = true);
    try {
      final id = await _carsRepo.createCarV2(
        listingType: _listingType,
        brand: _brand!.trim(),
        model: _model!.trim(),
        year: year!,
        mileage: mileage,
        price: price, // null → «Договорная»
        city: _city!.trim(),
        photoUrls: _photoUrls,
        bodyType: _bodyType,
        transmission: _transmission,
        fuel: _fuel,
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
      );
      _snack('Объявление отправлено на модерацию');
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) context.pop(id);
      }
    } catch (e) {
      _snack('Ошибка публикации: $e');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Подать объявление')),
      body: AbsorbPointer(
        absorbing: _publishing,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---------- Тип объявления ----------
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'sale', label: Text('Продажа')),
                ButtonSegment(value: 'rent', label: Text('Аренда')),
                ButtonSegment(value: 'both', label: Text('Оба')),
              ],
              selected: {_listingType},
              onSelectionChanged: (s) =>
                  setState(() => _listingType = s.first),
            ),
            const SizedBox(height: 16),

            // ---------- Город (первым полем, справочник + ручной ввод) ----------
            _pickerField(
              label: 'Город',
              value: _city,
              onTap: () => _pick(
                title: 'Город',
                options: ReferenceData.cities,
                current: _city,
                allowCustom: true,
                onPicked: (v) => setState(() => _city = v),
              ),
            ),
            const SizedBox(height: 12),

            // ---------- Марка (справочник + ручной ввод) ----------
            _pickerField(
              label: 'Марка',
              value: _brand,
              onTap: () => _pick(
                title: 'Марка',
                options: _brands.isNotEmpty ? _brands : ReferenceData.brands,
                current: _brand,
                allowCustom: true,
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

            // ---------- Модель — появляется ТОЛЬКО когда выбрана марка ----------
            if (_brand != null) ...[
              const SizedBox(height: 12),
              if (_loadingModels)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              else
                _pickerField(
                  label: 'Модель',
                  value: _model,
                  hint: 'Выберите',
                  onTap: () => _pick(
                    title: 'Модель',
                    options: _models,
                    current: _model,
                    allowCustom: true,
                    onPicked: (v) => setState(() => _model = v),
                  ),
                ),
            ],
            const SizedBox(height: 12),

            // ---------- Год выпуска ----------
            _pickerField(
              label: 'Год выпуска',
              value: _year,
              onTap: () => _pick(
                title: 'Год выпуска',
                options: _years,
                current: _year,
                onPicked: (v) => setState(() => _year = v),
              ),
            ),
            const SizedBox(height: 12),

            // ---------- Пробег (свободный ввод) ----------
            _numField(_mileageCtrl, 'Пробег, км', hint: 'Необязательно'),
            const SizedBox(height: 12),

            // ---------- Цена (свободный ввод) ----------
            _numField(
              _priceCtrl,
              _listingType == 'rent' ? 'Цена аренды в сутки, EUR' : 'Цена, EUR',
              hint: 'Договорная',
            ),
            const SizedBox(height: 12),

            // ---------- Кузов / КПП / Топливо (необязательные) ----------
            _pickerField(
              label: 'Тип кузова',
              value: _bodyType == null ? null : ReferenceData.bodyTypes[_bodyType],
              hint: 'Не указано',
              onTap: () => _pickMap(
                title: 'Тип кузова',
                items: ReferenceData.bodyTypes,
                current: _bodyType,
                onPicked: (v) => setState(() => _bodyType = v),
              ),
            ),
            const SizedBox(height: 12),
            _pickerField(
              label: 'Коробка передач',
              value: _transmission == null
                  ? null
                  : ReferenceData.transmissions[_transmission],
              hint: 'Не указано',
              onTap: () => _pickMap(
                title: 'Коробка передач',
                items: ReferenceData.transmissions,
                current: _transmission,
                onPicked: (v) => setState(() => _transmission = v),
              ),
            ),
            const SizedBox(height: 12),
            _pickerField(
              label: 'Топливо',
              value: _fuel == null ? null : ReferenceData.fuels[_fuel],
              hint: 'Не указано',
              onTap: () => _pickMap(
                title: 'Топливо',
                items: ReferenceData.fuels,
                current: _fuel,
                onPicked: (v) => setState(() => _fuel = v),
              ),
            ),
            const SizedBox(height: 12),

            // ---------- Описание (необязательно, до 6000 символов) ----------
            TextField(
              controller: _descCtrl,
              maxLines: 5,
              minLines: 3,
              maxLength: 6000,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Описание',
                hintText: 'Состояние, комплектация, история…',
                hintStyle: _hintStyle,
                alignLabelWithHint: true,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // ---------- Фото (до 10) ----------
            Text('Фотографии (${_photoUrls.length}/$_maxPhotos)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _PhotoStrip(
              urls: _photoUrls,
              uploading: _uploading,
              canAdd: _photoUrls.length < _maxPhotos,
              onAdd: _pickAndUpload,
              onRemove: (i) => setState(() => _photoUrls.removeAt(i)),
            ),

            const SizedBox(height: 24),

            // ---------- Публикация ----------
            FilledButton(
              onPressed: _publishing ? null : _publish,
              child: _publishing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Опубликовать'),
            ),
            const SizedBox(height: 8),
            Text(
              'После публикации объявление уходит на модерацию и появится '
              'в каталоге после одобрения.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Поле-пикер — идентично фильтрам (тот же вид и размер шрифта значения).
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
              value ?? (hint ?? 'Выберите'),
              style: TextStyle(color: value == null ? Colors.grey : null),
            ),
            if (enabled) const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  // Единый стиль подсказки-плейсхолдера: мелкий и тусклый, как «Не указано»
  // в пикерах. Используется для hint в текстовых полях.
  static const TextStyle _hintStyle =
      TextStyle(color: Colors.grey, fontSize: 14);

  // Числовое поле: только цифры, сумма форматируется как «1 000».
  // Лейбл — в разрыве рамки, подсказка (hint) — серым внутри поля.
  Widget _numField(TextEditingController ctrl, String label, {String? hint}) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [_ThousandsFormatter()],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: _hintStyle,
        // Лейбл всегда «поднят» в рамку, чтобы hint не сливался с ним.
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

// Форматтер: оставляет только цифры и разбивает на разряды пробелом
// (например, 1000000 → «1 000 000»). Курсор ставим в конец.
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    // Разбиваем на группы по 3 справа налево.
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ============================================================
// Полноэкранный выбор из списка со строкой поиска и (опционально)
// возможностью ВВЕСТИ СВОЁ значение, если его нет в справочнике.
// Возвращает выбранное/введённое значение или null при отмене.
// ============================================================
class _SelectScreen extends StatefulWidget {
  const _SelectScreen({
    required this.title,
    required this.options,
    required this.current,
    this.allowCustom = false,
  });

  final String title;
  final List<String> options;
  final String? current;
  final bool allowCustom;

  @override
  State<_SelectScreen> createState() => _SelectScreenState();
}

class _SelectScreenState extends State<_SelectScreen> {
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

    // Точного совпадения введённого текста с опциями нет → предлагаем «Указать своё».
    final trimmed = _query.trim();
    final showCustom = widget.allowCustom &&
        trimmed.isNotEmpty &&
        !widget.options.any((o) => o.toLowerCase() == trimmed.toLowerCase());

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
              decoration: InputDecoration(
                hintText: widget.allowCustom ? 'Поиск или ввод своего…' : 'Поиск…',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                // Опция «Указать своё» — вверху, когда введён новый текст.
                if (showCustom)
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: Text('Указать «$trimmed»'),
                    onTap: () => Navigator.pop(context, trimmed),
                  ),
                if (showCustom) const Divider(height: 1),
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

// Горизонтальная лента миниатюр фото + кнопка добавления
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.urls,
    required this.uploading,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> urls;
  final bool uploading;
  final bool canAdd; // false → достигнут лимит, кнопку добавления прячем
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Кнопка добавления — только пока не достигнут лимит
          if (canAdd || uploading)
            GestureDetector(
              onTap: uploading ? null : onAdd,
              child: Container(
                width: 100,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: uploading
                    ? const Center(child: CircularProgressIndicator())
                    : const Icon(Icons.add_a_photo, size: 32),
              ),
            ),
          // Миниатюры загруженных фото
          for (int i = 0; i < urls.length; i++)
            Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(urls[i]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 4,
                  child: GestureDetector(
                    onTap: () => onRemove(i),
                    child: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

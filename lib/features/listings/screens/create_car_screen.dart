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
import '../../auth/screens/login_screen.dart';
import '../../../data/models/car_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/cars_repository.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/utils/serbian_phone.dart';
import '../../../shared/widgets/app_button_colors.dart';
import '../../../shared/widgets/dark_pill_button.dart';
import '../utils/generate_temp_uuid.dart';
import '../utils/validate_car_form.dart';
import '../../../shared/widgets/pill_back_button.dart';

class CreateCarScreen extends StatefulWidget {
  const CreateCarScreen({super.key, this.editCar});

  // Если задано — режим РЕДАКТИРОВАНИЯ существующего объявления (поля
  // предзаполняются, вызывается update_car_v2). null — создание нового.
  final CarModel? editCar;

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
  // Контактный телефон (сербский мобильный)
  final _phoneCtrl = TextEditingController();
  // Фокус телефона: при входе в пустое поле сразу показываем префикс «+381 ».
  final _phoneFocus = FocusNode();

  // Максимум фото на одно объявление
  static const int _maxPhotos = 10;

  // Марки из справочника (грузятся из БД при открытии)
  List<String> _brands = [];
  // Модели выбранной марки
  List<String> _models = [];
  bool _loadingModels = false;

  // Тип объявления: null (ещё не выбран) | 'sale' | 'rent'. Обязателен —
  // проверяется при «Опубликовать». В режиме редактирования выставляется из
  // самого объявления (см. _prefillFromCar).
  String? _listingType;

  // Подписи типа для пикера (ключ БД → текст пользователю).
  static const Map<String, String> _listingTypeLabels = {
    'sale': 'Продажа',
    'rent': 'Аренда',
  };

  // Загруженные публичные URL фото (по порядку)
  final List<String> _photoUrls = [];

  bool _uploading = false;
  bool _publishing = false;
  // true после успешной публикации — тогда временные фото НЕ удаляем
  // при уходе (они уже привязаны к объявлению).
  bool _published = false;

  // Режим редактирования (передан editCar).
  bool get _isEdit => widget.editCar != null;

  @override
  void initState() {
    super.initState();
    _loadBrands();
    _phoneFocus.addListener(_onPhoneFocus);
    if (_isEdit) _prefillFromCar(widget.editCar!);
  }

  // Предзаполнение формы полями редактируемого объявления.
  void _prefillFromCar(CarModel car) {
    _listingType = car.isForRent && !car.isForSale ? 'rent' : 'sale';
    _brand = car.brand;
    _model = car.model;
    _year = '${car.year}';
    _city = car.city;
    _bodyType = car.bodyType?.value;
    _transmission = car.transmission?.value;
    _fuel = car.fuel?.value;
    if (car.mileage != null) _mileageCtrl.text = '${car.mileage}';
    final price = car.isForRent ? car.rentPriceDaily : car.salePrice;
    if (price != null) _priceCtrl.text = price.toStringAsFixed(0);
    _descCtrl.text = car.description ?? '';
    if (car.contactPhone != null) {
      _phoneCtrl.text = serbianPhoneDisplay(car.contactPhone!);
    }
    // Существующие фото объявления — сразу в набор (можно удалять/добавлять).
    _loadExistingPhotos(car.id);
    // Модели выбранной марки для пикера.
    if (car.brand.isNotEmpty) _loadModels(car.brand);
  }

  // Подтягиваем URL уже загруженных фото объявления.
  Future<void> _loadExistingPhotos(String carId) async {
    try {
      final imgs = await _carsRepo.fetchImages(carId);
      if (!mounted) return;
      setState(() {
        _photoUrls
          ..clear()
          ..addAll(imgs.map((e) => e.imageUrl));
      });
    } catch (_) {
      // Не критично — пользователь добавит фото заново.
    }
  }

  // При фокусе на пустом поле подставляем «+381 » — сербский код виден сразу.
  // При потере фокуса, если остался только префикс без номера, очищаем поле,
  // чтобы «Телефон» не выглядел заполнённым и hint был виден.
  void _onPhoneFocus() {
    if (_phoneFocus.hasFocus) {
      if (_phoneCtrl.text.trim().isEmpty) {
        _phoneCtrl.text = '+381 ';
        _phoneCtrl.selection = TextSelection.collapsed(
          offset: _phoneCtrl.text.length,
        );
      }
    } else {
      // Только префикс (нет ни одной цифры номера) → сбрасываем.
      final digits = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits == '381') _phoneCtrl.clear();
    }
  }

  @override
  void dispose() {
    // Ушёл, не опубликовав, но фото уже загружены → чистим временные файлы
    // из Storage (в БД их ещё нет). Fire-and-forget: экран уже закрывается.
    if (!_published && _photoUrls.isNotEmpty) {
      _carsRepo.deleteTempCarImages(_tempCarUuid);
    }
    _mileageCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _phoneFocus.removeListener(_onPhoneFocus);
    _phoneFocus.dispose();
    _phoneCtrl.dispose();
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
    showAppSnack(context, msg);
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
    bool allowNone = true, // false — без опции «— Не указано —» (обязательное поле)
  }) async {
    final currentLabel = current == null ? null : items[current];
    await _pick(
      title: title,
      options: [if (allowNone) '— Не указано —', ...items.values],
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

  // Гарантирует наличие аккаунта: если пользователь ещё не вошёл — показывает
  // окно «Подтвердите номер», затем экран ввода кода из SMS. Возвращает true,
  // когда после вызова пользователь авторизован (уже был или только что вошёл).
  // Используется и для загрузки фото (Storage требует uid), и для публикации.
  Future<bool> _ensureAuth() async {
    if (_auth.currentUser != null) return true;

    final agreed = await _confirmPhoneDialog();
    if (!mounted || agreed != true) return false; // «Отмена» — не входим

    // Открываем вход обычным Navigator.push (не через go_router), чтобы
    // редирект-гард роутера не перехватил экран и не увёл на /catalog при
    // смене auth-состояния. По успеху LoginScreen сам делает Navigator.pop(true)
    // и мы возвращаемся сюда — на форму — для продолжения (кнопка «Опубликовать»).
    final loggedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoginScreen(prefillPhone: _phoneCtrl.text),
      ),
    );
    if (!mounted) return false;
    return loggedIn == true && _auth.currentUser != null;
  }

  // Выбор фото из галереи и загрузка в Storage
  Future<void> _pickAndUpload() async {
    // Storage привязан к uid (RLS): гость грузить не может. Поэтому перед
    // выбором фото требуем подтверждение номера. Отказ — просто выходим.
    if (!await _ensureAuth()) return;
    if (!mounted) return;

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
      _snack('Не удалось загрузить часть фото: ${humanizeError(e)}');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // Окно-предупреждение перед входом: «Подтвердите номер телефона».
  // Показывает номер из формы (если введён) и кнопку «Хорошо» (+ «Отмена»).
  // Возвращает true, если пользователь согласился перейти к вводу кода.
  Future<bool?> _confirmPhoneDialog() {
    final phone = _phoneCtrl.text.trim();
    final hasPhone = serbianPhoneToE164(phone) != null;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтвердите номер телефона'),
        content: Text(
          hasPhone
              ? 'Подтвердите свой номер $phone — мы отправим код в SMS.'
              : 'Для размещения объявления нужно подтвердить номер телефона — '
                  'мы отправим код в SMS.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Хорошо'),
          ),
        ],
      ),
    );
  }

  // Публикация объявления
  Future<void> _publish() async {
    // Тип объявления обязателен (первое поле формы) — сервер требует 'sale'/'rent'.
    if (_listingType == null) {
      _snack('Выберите тип объявления: продажа или аренда');
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
      _phoneCtrl.text,
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

    // На этот момент пользователь ГАРАНТИРОВАННО вошёл: фото обязательны
    // (validateCarForm требует ≥1 фото), а их загрузка проходит через
    // _ensureAuth. Отдельный запрос кода здесь не нужен — оставляем лишь
    // страховку на случай пропавшей сессии (тогда просто не публикуем).
    if (_auth.currentUser == null) {
      _snack('Сессия истекла — добавьте фото заново, чтобы подтвердить номер');
      return;
    }

    // Согласие с политикой не спрашиваем здесь: публикация проходит через
    // SMS-вход (_ensureAuth при загрузке фото), а политика принимается один
    // раз именно на входе.

    // Телефон в БД хранится в E.164 без пробелов (constraint
    // cars_contact_phone_serbian: ^\+381[1-36]\d{7,8}$). Поле ввода содержит
    // пробелы («+381 64 123 456») — приводим к слитному виду перед отправкой.
    final phoneE164 = serbianPhoneToE164(_phoneCtrl.text);
    if (phoneE164 == null) {
      _snack('Введите корректный номер телефона');
      return;
    }

    setState(() => _publishing = true);
    try {
      final description =
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
      final String id;
      if (_isEdit) {
        // Редактирование: обновляем объявление, статус → снова на модерацию.
        id = await _carsRepo.updateCarV2(
          carId: widget.editCar!.id,
          listingType: _listingType!,
          brand: _brand!.trim(),
          model: _model!.trim(),
          year: year!,
          mileage: mileage,
          price: price,
          city: _city!.trim(),
          photoUrls: _photoUrls,
          bodyType: _bodyType,
          transmission: _transmission,
          fuel: _fuel,
          description: description,
          phone: phoneE164,
        );
      } else {
        id = await _carsRepo.createCarV2(
          listingType: _listingType!,
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
          description: description,
          phone: phoneE164,
        );
      }
      // Готово: фото привязаны к объявлению — при уходе с экрана не удаляем.
      _published = true;
      _snack(_isEdit
          ? 'Изменения отправлены на модерацию'
          : 'Объявление отправлено на модерацию');
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) context.pop(id);
      }
    } catch (e) {
      final msg = humanizeError(e);
      // Сообщение о дубле уже самодостаточное («У вас уже есть такое…») —
      // показываем как есть, без префикса «Ошибка публикации».
      final isDuplicate = msg.contains('уже есть такое объявление');
      _snack(isDuplicate ? msg : 'Ошибка публикации: $msg');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: const PillBackButton(),
          title: Text(_isEdit ? 'Редактирование' : 'Новое объявление')),
      body: AbsorbPointer(
        absorbing: _publishing,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---------- Тип объявления (обязательное поле-пикер) ----------
            _pickerField(
              label: 'Тип объявления',
              value: _listingType == null
                  ? null
                  : _listingTypeLabels[_listingType],
              hint: 'Продажа или аренда',
              onTap: () => _pickMap(
                title: 'Тип объявления',
                items: _listingTypeLabels,
                current: _listingType,
                allowNone: false, // тип обязателен — «Не указано» не предлагаем
                onPicked: (v) => setState(() => _listingType = v),
              ),
            ),
            const SizedBox(height: 12),

            // ---------- Город (справочник + ручной ввод) ----------
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
              // Заглавная в начале и после . ! ? — подсказка клавиатуре плюс
              // форматтер, гарантирующий результат независимо от неё.
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [_SentenceCaseFormatter()],
              decoration: const InputDecoration(
                labelText: 'Описание',
                hintText: 'Состояние, комплектация, история…',
                hintStyle: _hintStyle,
                alignLabelWithHint: true,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            // ---------- Контактный телефон (обязательное, сербский моб./гор.) ----------
            TextField(
              controller: _phoneCtrl,
              focusNode: _phoneFocus,
              keyboardType: TextInputType.phone,
              inputFormatters: [SerbianPhoneFormatter()],
              decoration: const InputDecoration(
                labelText: 'Телефон',
                hintText: '+381 6X XXX XXX',
                hintStyle: _hintStyle,
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

            // ---------- Публикация / сохранение (тёмная плашка) ----------
            DarkPillButton(
              label: _publishing
                  ? 'Сохраняем…'
                  : (_isEdit ? 'Сохранить и отправить' : 'Опубликовать'),
              variant: PillVariant.green,
              onTap: _publishing ? null : _publish,
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

// Форматтер: делает заглавной первую букву предложения — в начале текста и
// после . ! ? (с учётом пробелов/переводов строк). Длину текста не меняет,
// поэтому позицию курсора из newValue сохраняем как есть.
class _SentenceCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final chars = text.split('');
    // capitalizeNext = true → следующую БУКВУ делаем заглавной.
    var capitalizeNext = true;
    for (int i = 0; i < chars.length; i++) {
      final c = chars[i];
      if (c.trim().isEmpty) {
        continue; // пробелы/переводы строк не меняют флаг
      }
      if (capitalizeNext) {
        chars[i] = c.toUpperCase();
        capitalizeNext = false;
      }
      // После завершающего знака препинания — следующее слово с заглавной.
      if (c == '.' || c == '!' || c == '?') {
        capitalizeNext = true;
      }
    }
    return TextEditingValue(
      text: chars.join(),
      selection: newValue.selection,
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
      appBar: AppBar(leading: const PillBackButton(), title: Text(widget.title)),
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

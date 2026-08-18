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

import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_brand.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/config/reference_data.dart';
import '../../auth/screens/login_screen.dart';
import '../../../data/models/car_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/cars_repository.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/utils/number_formatters.dart';
import '../../../shared/utils/serbian_phone.dart';
import '../../../shared/widgets/app_search_header.dart';
import '../../../shared/widgets/app_close_button.dart';
import '../../../shared/widgets/app_button_colors.dart';
import '../../../shared/widgets/dark_pill_button.dart';
import '../utils/generate_temp_uuid.dart';
import '../utils/validate_car_form.dart';
import '../../../shared/widgets/pill_back_button.dart';

class CreateCarScreen extends StatefulWidget {
  const CreateCarScreen({super.key, this.editCar, this.duplicateFrom});

  // Если задано — режим РЕДАКТИРОВАНИЯ существующего объявления (поля
  // предзаполняются, вызывается update_car_v2). null — создание нового.
  final CarModel? editCar;

  // Дублирование: поля предзаполняются из существующего объявления, но
  // создаётся НОВОЕ (create_car_v2). Отличие от editCar принципиальное —
  // при дублировании id исходного объявления не используется, иначе
  // продавец вместо копии перезаписал бы оригинал.
  //
  // Фото не переносятся: они лежат в Storage по пути исходного объявления,
  // и копировать их пришлось бы через сервер. Продавец, дублирующий
  // объявление, обычно всё равно снимает новую машину заново.
  final CarModel? duplicateFrom;

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

  // Максимум фото на одно объявление — из общей константы, а не
  // своим числом. Раньше здесь стояло локальное 10 при
  // AppConstants.maxCarImages = 15: два разных лимита в одном
  // приложении, и какой сработает, зависело от экрана.
  static const int _maxPhotos = AppConstants.maxCarImages;

  // Марки из справочника (грузятся из БД при открытии)
  List<String> _brands = [];
  // Модели выбранной марки
  List<String> _models = [];
  bool _loadingModels = false;

  // Тип объявления: 'sale' | 'rent'. По умолчанию 'sale' — «Продаю»
  // подсвечено сразу, как на сайте (useState('sale') в SellForm).
  // Продажа — подавляющее большинство объявлений, и требовать явного
  // выбора там, где он почти всегда один и тот же, значит добавлять
  // лишний шаг на первом же экране.
  //
  // Тип остаётся ОБЯЗАТЕЛЬНЫМ полем: проверка при публикации сохранена
  // как страховка — поле nullable, и снять значение может режим
  // редактирования (_prefillFromCar) или будущая правка формы.
  String? _listingType = 'sale';

  // Текст последней ошибки валидации: показывается над кнопкой публикации
  // и сбрасывается при новой попытке.
  String? _validationError;

  // Подписи типа для сегмента (ключ БД → текст пользователю). Метод, а
  // не константа: подписи зависят от языка и берутся из словаря.
  // Подписи от ПЕРВОГО ЛИЦА («Продаю» / «Сдаю»), как на сайте, а не
  // «Продажа»/«Аренда» из фильтров. Разница не косметическая: в фильтрах
  // это категория выдачи, а здесь — действие самого продавца, и вопрос
  // формы звучит «что вы делаете с машиной».
  Map<String, String> _listingTypeLabels(BuildContext context) => {
        'sale': context.t.sellTypeSale,
        'rent': context.t.sellTypeRent,
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

  // Дублирование: поля заполнены, но сохранение создаёт новое объявление.
  bool get _isDuplicate => widget.duplicateFrom != null;

  @override
  void initState() {
    super.initState();
    _loadBrands();
    _phoneFocus.addListener(_onPhoneFocus);
    if (_isEdit) {
      _prefillFromCar(widget.editCar!);
    } else if (_isDuplicate) {
      // copyPhotos: false — фото исходного объявления не переносим,
      // иначе они оказались бы привязаны сразу к двум объявлениям.
      _prefillFromCar(widget.duplicateFrom!, copyPhotos: false);
    }
  }

  // Предзаполнение формы полями существующего объявления.
  // copyPhotos = false при дублировании (см. комментарий выше).
  void _prefillFromCar(CarModel car, {bool copyPhotos = true}) {
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
    if (copyPhotos) _loadExistingPhotos(car.id);
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

  /// Ошибка валидации: и всплывающей подсказкой, и текстом над кнопкой.
  /// Снэкбар замечают сразу, надпись остаётся, пока причину не устранят.
  // [onStep] — шаг, на котором находится поле с ошибкой. Публикация идёт
  // с последнего шага, а валидация проверяет ВСЕ поля разом: при
  // редактировании объявления ошибка может относиться к марке (шаг 1)
  // или цене (шаг 2). Без возврата человек читал бы «укажите марку»,
  // стоя на экране с одним телефоном, и не понимал, куда идти.
  void _failValidation(String msg, {int? onStep}) {
    if (!mounted) return;
    setState(() {
      _validationError = msg;
      if (onStep != null) _step = onStep;
    });
    showAppSnack(context, msg, isError: true);
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
      options: [if (allowNone) context.t.formNotSet, ...items.values],
      current: currentLabel,
      onPicked: (picked) {
        if (picked == null || picked == context.t.formNotSet) {
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

    // Тексты берём ДО await: после него виджет мог быть снят с дерева.
    final photoFailed = context.t.createPhotoFailed;
    final t = context.t;

    // Сколько ещё можно добавить до лимита
    final remaining = _maxPhotos - _photoUrls.length;
    if (remaining <= 0) {
      _snack(context.t.photoLimit(_maxPhotos));
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
      _snack(t.photoTrimmed(remaining, files.length, _maxPhotos));
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
      _snack('$photoFailed: ${humanizeError(e)}');
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
        title: Text(context.t.createConfirmPhoneTitle),
        content: Text(
          hasPhone
              ? context.t.confirmPhoneBody(phone)
              : '${context.t.createPhoneRequired} — '
                  '${context.t.createPhoneNoteSuffix}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t.commonOk),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // ПОШАГОВАЯ ПОДАЧА — зеркало SellForm сайта.
  // ------------------------------------------------------------
  // Раньше форма была одной простынёй из двенадцати полей: человек
  // видел сразу и марку, и топливо, и телефон, и бросал её, не начав.
  // Шаги те же, что на сайте: Автомобиль → Детали → Фото → Контакты.
  //
  // Порядок неслучаен: сначала то, что продавец знает наизусть, и лишь
  // в конце — телефон. На сайте по той же причине вход по SMS стоит
  // последним шагом.
  //
  // ВАЖНО: разбивка чисто визуальная. Валидация и публикация (_publish,
  // validateCarForm, create_car_v2) не тронуты — они по-прежнему видят
  // все поля разом, и порядок вызовов RPC прежний.
  int _step = 1;

  static const int _stepsTotal = 4;

  // Шаг 1 пройден: тип, марка, модель, год и город заполнены. Те же
  // условия, что у canNext1 на сайте.
  bool get _canLeaveStep1 =>
      _listingType != null &&
      (_brand?.trim().isNotEmpty ?? false) &&
      (_model?.trim().isNotEmpty ?? false) &&
      (_year?.trim().isNotEmpty ?? false) &&
      (_city?.trim().isNotEmpty ?? false);

  void _goToStep(int next) {
    // Смена шага снимает прежнюю ошибку: её причина осталась на другом
    // экране, и висеть над чужой кнопкой она не должна.
    setState(() {
      _validationError = null;
      _step = next;
    });
  }

  // Переход с шага «Фото». Как на сайте (goToContacts): без единого
  // снимка дальше не пускаем — объявление без фото почти не получает
  // откликов. Проверка именно здесь, а не при публикации, иначе
  // продавец узнал бы о ней после заполнения телефона.
  void _goToContacts() {
    if (_photoUrls.isEmpty) {
      _failValidation(context.t.sellErrPhotosRequired);
      return;
    }
    _goToStep(4);
  }

  // Шаг, на котором лежит первое незаполненное обязательное поле.
  // Порядок совпадает с порядком проверок в validateCarForm, поэтому
  // возвращённый шаг всегда соответствует показанному тексту ошибки.
  int _stepOfFirstEmptyField() {
    final noCity = !(_city?.trim().isNotEmpty ?? false);
    final noBrand = !(_brand?.trim().isNotEmpty ?? false);
    final noModel = !(_model?.trim().isNotEmpty ?? false);
    final noYear = int.tryParse(_year ?? '') == null;
    if (noCity || noBrand || noModel || noYear) return 1;

    // Телефон проверяется раньше фото (см. validateCarForm), но живёт
    // на последнем шаге — возвращать туда не нужно, мы уже там.
    if (_photoUrls.isEmpty) return 3;
    return 4;
  }

  // Перестановка фотографии на одну позицию. Порядок в _photoUrls —
  // это и есть порядок в объявлении: первый элемент попадает в каталог
  // обложкой, и RPC получает список как есть, без отдельного поля
  // «главная». Логика публикации при этом не меняется.
  void _movePhoto(int index, int direction) {
    final target = index + direction;
    if (target < 0 || target >= _photoUrls.length) return;

    setState(() {
      final moved = _photoUrls.removeAt(index);
      _photoUrls.insert(target, moved);
    });
  }

  // Ряд кнопок под шагом: «Назад» слева, главное действие справа.
  // На первом шаге «Назад» нет — уходить некуда, там работает крестик.
  Widget _stepNav({required Widget next, bool showBack = true}) {
    if (!showBack) return next;
    return Row(
      children: [
        Expanded(
          child: DarkPillButton(
            label: context.t.sellBack,
            variant: PillVariant.outline,
            expand: true,
            onTap: () => _goToStep(_step - 1),
          ),
        ),
        const SizedBox(width: AppBrandSpacing.sm),
        Expanded(flex: 2, child: next),
      ],
    );
  }

  // Публикация объявления
  Future<void> _publish() async {
    // Новая попытка — снимаем прежнюю ошибку: иначе старый текст висел бы
    // под кнопкой уже после того, как причину устранили.
    if (_validationError != null) setState(() => _validationError = null);

    // Текст успеха берём ДО сетевых вызовов: после await виджет мог быть
    // снят с дерева, и обращение к context стало бы небезопасным.
    final sentMessage =
        _isEdit ? context.t.createEditSent : context.t.createSentToModeration;
    final publishFailed = context.t.createPublishFailed;
    // Тип объявления обязателен (первое поле формы) — сервер требует 'sale'/'rent'.
    if (_listingType == null) {
      _failValidation(context.t.createTypeRequired, onStep: 1);
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
      t: context.t,
    );
    if (err != null) {
      // validateCarForm возвращает только текст, поэтому шаг определяем
      // по самим полям — в том же порядке, в каком их проверяет функция.
      // Трогать её сигнатуру ради этого нельзя: она общая с формой
      // редактирования и вызывается из другого места.
      _failValidation(err, onStep: _stepOfFirstEmptyField());
      return;
    }
    // Если цена введена, но некорректна (например, 0) — предупреждаем.
    if (priceDigits.isNotEmpty && (price == null || price <= 0)) {
      _failValidation(context.t.createPricePositive, onStep: 2);
      return;
    }
    if (_uploading) {
      _failValidation(context.t.createWaitPhotos, onStep: 3);
      return;
    }

    // На этот момент пользователь ГАРАНТИРОВАННО вошёл: фото обязательны
    // (validateCarForm требует ≥1 фото), а их загрузка проходит через
    // _ensureAuth. Отдельный запрос кода здесь не нужен — оставляем лишь
    // страховку на случай пропавшей сессии (тогда просто не публикуем).
    if (_auth.currentUser == null) {
      _snack(context.t.createSessionExpired);
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
      _snack(context.t.loginPhoneInvalid);
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
      _snack(sentMessage);
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) context.pop(id);
      }
    } catch (e) {
      final msg = humanizeError(e);
      // Сообщение о дубле приходит с сервера уже самодостаточным —
      // показываем как есть, без префикса «Ошибка публикации».
      //
      // Признак ищем по коду ошибки Postgres, а не по русской подстроке:
      // раньше проверка была на текст «уже есть такое объявление» и на
      // сербском интерфейсе не срабатывала.
      final isDuplicate = e.toString().contains('23505') ||
          e.toString().contains('duplicate');
      _snack(isDuplicate ? msg : '$publishFailed: $msg');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppBrandColors.bg,
      // AppBar убран: вместо него — та же шапка, что в каталоге,
      // избранном и сообщениях (зеркало SiteHeader сайта). На сайте
      // шапка видна и во время заполнения формы, а не подменяется
      // заголовком экрана.
      body: SafeArea(
        child: Column(
          children: [
            // ФИКСИРОВАННАЯ шапка — не уезжает при скролле формы.
            const AppSearchHeader(),

            Expanded(
              child: AbsorbPointer(
                absorbing: _publishing,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ---------- Заголовок страницы ----------
                    // СНАРУЖИ карточки, как на сайте (SellPageView):
                    // h1 и подпись стоят над формой, а не внутри неё.
                    // Показываем только при СОЗДАНИИ: при редактировании
                    // «Продайте автомобиль» противоречило бы происходящему.
                    if (!_isEdit) ...[
                      Text(
                        context.t.sellTitle,
                        style: AppBrandText.h2
                            .copyWith(color: AppBrandColors.neutral100),
                      ),
                      const SizedBox(height: AppBrandSpacing.sm),
                      Text(
                        context.t.sellSubtitle,
                        style: AppBrandText.body
                            .copyWith(color: AppBrandColors.neutral60),
                      ),
                      const SizedBox(height: AppBrandSpacing.lg),
                    ],

                    // ---------- Карточка формы ----------
                    // Все шаги живут ВНУТРИ одной рамки, как на сайте
                    // (components/ui/Card): белая подложка, граница
                    // neutral10, радиус card. Без неё поля лежали прямо
                    // на фоне экрана и форма не читалась как одно целое.
                    _FormCard(child: _buildCardContent()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Содержимое карточки: строка «Шаг N / 4» с крестиком, затем поля
  // текущего шага и ошибка валидации под ними.
  Widget _buildCardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---------- Счётчик шагов и выход ----------
        // Крестик стоит ЗДЕСЬ, в правом верхнем углу карточки, — ровно
        // как на сайте. В шапке экрана его быть не должно: там слева
        // у всех остальных экранов «назад», и два разных по смыслу
        // действия на одном месте путают.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: AppBrandSpacing.sm),
                child: Text(
                  '${context.t.sellStep} $_step / $_stepsTotal',
                  style: AppBrandText.caption
                      .copyWith(color: AppBrandColors.neutral50),
                ),
              ),
            ),
            // Отрицательные отступы возвращают знак к самому углу
            // карточки — зеркало «-mr-2 -mt-2» сайта. У кнопки область
            // 40px ради попадания пальцем, и без сдвига она отступала
            // бы от края заметно сильнее, чем текст рядом.
            Transform.translate(
              offset: const Offset(AppBrandSpacing.sm, -AppBrandSpacing.sm),
              child: AppCloseButton(
                tooltip: context.t.commonClose,
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppBrandSpacing.sm),

        if (_step == 1) ..._buildStepCar(),
        if (_step == 2) ..._buildStepDetails(),
        if (_step == 3) ..._buildStepPhotos(),
        if (_step == 4) ..._buildStepContact(),

        // Текст последней ошибки валидации — красным над кнопкой.
        // Снэкбар исчезает через несколько секунд, а причина отказа
        // нужна ровно в момент, когда человек снова тянется к CTA.
        if (_validationError != null) ...[
          // md (16) = «mt-4» сайта. На sm (8) плашка липла к кнопкам
          // и читалась как их продолжение, а не как отдельный блок.
          const SizedBox(height: AppBrandSpacing.md),
          // Ошибка лежит на РОЗОВОЙ ПЛАШКЕ, как на сайте
          // («rounded-control bg-brand-red/10 px-3 py-2»): красный текст
          // прямо на белом фоне терялся среди подписей полей, тогда как
          // заливка выделяет причину отказа как отдельный блок.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppBrandSpacing.sm + 4, // px-3
              vertical: AppBrandSpacing.sm,       // py-2
            ),
            decoration: BoxDecoration(
              // Тот же красный, что у текста, но с прозрачностью 10% —
              // ровно «bg-brand-red/10» сайта.
              color: AppBrandColors.error.withValues(alpha: 0.1),
              borderRadius: AppBrandRadius.controlAll,
            ),
            child: Text(
              _validationError!,
              textAlign: TextAlign.center,
              style:
                  AppBrandText.caption.copyWith(color: AppBrandColors.error),
            ),
          ),
        ],
      ],
    );
  }

  // ---------- Заголовок шага ----------
  Widget _stepTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppBrandSpacing.md),
        child: Text(
          text,
          style: AppBrandText.h4.copyWith(color: AppBrandColors.neutral100),
        ),
      );

  // Подпись НАД полем — как на сайте. У сегмента типа нет собственного
  // InputDecorator с floating label, и без подписи он читался бы как
  // две безымянные кнопки.
  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style:
              AppBrandText.caption.copyWith(color: AppBrandColors.neutral60),
        ),
      );

  // ============================================================
  // ШАГ 1 — АВТОМОБИЛЬ: тип, марка, модель, год, город.
  // ============================================================
  List<Widget> _buildStepCar() {
    return [
      _stepTitle(context.t.sellStepCar),

      // ---------- Тип объявления (обязательный, сегмент) ----------
      // Сегмент вместо пикера-списка: вариантов всего два, и открывать
      // ради них модальный лист — лишний шаг. Так же выбирается тип
      // на форме подачи сайта.
      _fieldLabel(context.t.formListingType),
      _ListingTypeSegment(
        value: _listingType,
        labels: _listingTypeLabels(context),
        onChanged: (v) => setState(() => _listingType = v),
      ),
      const SizedBox(height: 12),

      // ---------- Марка (справочник + ручной ввод) ----------
      // Порядок полей — как на сайте: марка и модель идут ПЕРЕД годом
      // и городом. Машину продавец описывает сверху вниз, от главного.
      _pickerField(
        label: context.t.formBrand,
        value: _brand,
        onTap: () => _pick(
          title: context.t.formBrand,
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
      const SizedBox(height: 12),

      // ---------- Модель ----------
      // Поле показывается ВСЕГДА, как на сайте: скрытое до выбора марки,
      // оно заставляло гадать, куда делась строка. Пока марки нет —
      // поле неактивно с подсказкой «Сначала выберите марку».
      //
      // Загрузка списка моделей меняет только ТЕКСТ в поле («Поиск…»),
      // как на сайте. Раньше на это время поле подменялось синей
      // полосой LinearProgressIndicator: строка прыгала, а сам индикатор
      // выбивался из формы — единственный яркий элемент на шаге.
      _pickerField(
        label: context.t.formModel,
        value: _model,
        // Во время загрузки поле неактивно: списка ещё нет, и открывать
        // пустой лист выбора незачем.
        enabled: _brand != null && !_loadingModels,
        hint: _brand == null
            ? context.t.pickerModelNoBrand
            : _loadingModels
                ? context.t.formSearchHint
                : context.t.formAny,
        onTap: () => _pick(
          title: context.t.formModel,
          options: _models,
          current: _model,
          allowCustom: true,
          onPicked: (v) => setState(() => _model = v),
        ),
      ),
      const SizedBox(height: 12),

      // ---------- Год и город в одной строке ----------
      // На сайте это grid-cols-2: два коротких поля рядом вместо двух
      // почти пустых строк.
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _pickerField(
              label: context.t.carYear,
              value: _year,
              onTap: () => _pick(
                title: context.t.carYear,
                options: _years,
                current: _year,
                onPicked: (v) => setState(() => _year = v),
              ),
            ),
          ),
          const SizedBox(width: AppBrandSpacing.sm),
          Expanded(
            child: _pickerField(
              label: context.t.formCity,
              value: _city,
              onTap: () => _pick(
                title: context.t.formCity,
                options: ReferenceData.cities,
                current: _city,
                allowCustom: true,
                onPicked: (v) => setState(() => _city = v),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppBrandSpacing.lg),

      // Кнопка неактивна, пока шаг не заполнен — как на сайте
      // (disabled={!canNext1}): отказ виден до нажатия, а не после.
      _stepNav(
        showBack: false,
        next: DarkPillButton(
          label: context.t.sellNext,
          variant: PillVariant.green,
          expand: true,
          onTap: _canLeaveStep1 ? () => _goToStep(2) : null,
        ),
      ),
    ];
  }

  // ============================================================
  // ШАГ 2 — ДЕТАЛИ: цена, пробег, кузов, КПП, топливо, описание.
  // ============================================================
  List<Widget> _buildStepDetails() {
    return [
      _stepTitle(context.t.sellStepDetails),

      // ---------- Цена (свободный ввод) ----------
      // Первой: на сайте шаг «Детали» тоже открывается ценой — это
      // главный вопрос к объявлению после самой машины.
      _numField(
        _priceCtrl,
        _listingType == 'rent'
            ? context.t.formRentPrice
            : context.t.createPriceLabel,
        // Отдельный ключ, а не общий priceNegotiable: тот стоит
        // ВМЕСТО суммы на карточке и в каталоге, и «Цена договорная»
        // читалось бы там как «Цена: Цена договорная».
        hint: context.t.sellPriceNegotiableHint,
      ),
      const SizedBox(height: 12),

      // ---------- Пробег (свободный ввод) ----------
      // Без заглушки «Необязательно»: на сайте поле пустое, а
      // необязательность видна по отсутствию звёздочки у подписи.
      _numField(_mileageCtrl, context.t.formMileage),
      const SizedBox(height: 12),

      // ---------- Кузов / КПП / Топливо (необязательные) ----------
      // ТРИ В РЯД, как grid-cols-3 сайта. Раньше каждый пикер занимал
      // свою строку: шаг вытягивался на полтора экрана, хотя значения
      // короткие («Седан», «Автомат», «Дизель») и умещаются втроём.
      //
      // Подписи «Кузов» и «Коробка» — короткие варианты: «Тип кузова»
      // и «Коробка передач» в колонке шириной в треть экрана
      // обрезались бы многоточием.
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _pickerField(
              label: context.t.formBodyType,
              value:
                  _bodyType == null ? null : context.t.bodyTypeLabel(_bodyType!),
              onTap: () => _pickMap(
                title: context.t.formBodyType,
                items: context.t.bodyTypes,
                current: _bodyType,
                onPicked: (v) => setState(() => _bodyType = v),
              ),
            ),
          ),
          const SizedBox(width: AppBrandSpacing.sm),
          Expanded(
            child: _pickerField(
              label: context.t.formTransmission,
              value: _transmission == null
                  ? null
                  : context.t.transmissionLabel(_transmission!),
              onTap: () => _pickMap(
                title: context.t.formTransmission,
                items: context.t.transmissions,
                current: _transmission,
                onPicked: (v) => setState(() => _transmission = v),
              ),
            ),
          ),
          const SizedBox(width: AppBrandSpacing.sm),
          Expanded(
            child: _pickerField(
              label: context.t.carFuel,
              value: _fuel == null ? null : context.t.fuelLabel(_fuel!),
              onTap: () => _pickMap(
                title: context.t.carFuel,
                items: context.t.fuels,
                current: _fuel,
                onPicked: (v) => setState(() => _fuel = v),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),

      // ---------- Описание (необязательно, до 6000 символов) ----------
      // Подпись строкой над полем — как у остальных полей формы.
      _fieldLabel(context.t.carDescription),
      TextField(
        controller: _descCtrl,
        maxLines: 5,
        minLines: 5,
        maxLength: 6000,
        // counterText пустой: счётчик «0/6000» под пустым полем — шум.
        // На сайте его нет, ограничение там задано атрибутом maxLength
        // и всплывает только когда предел действительно близок.
        buildCounter: (_,
                {required currentLength, required isFocused, maxLength}) =>
            null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        // Заглавная в начале и после . ! ? — подсказка клавиатуре плюс
        // форматтер, гарантирующий результат независимо от неё.
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: [_SentenceCaseFormatter()],
        style: AppBrandText.body.copyWith(color: AppBrandColors.neutral100),
        decoration: InputDecoration(
          hintText: context.t.carDescriptionHint,
          alignLabelWithHint: true,
          // Как и у числовых полей: в теме isDense: true, и без явного
          // отключения многострочное поле поджимается по вертикали.
          isDense: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppBrandSpacing.sm + 4,
            vertical: AppBrandSpacing.sm + 4,
          ),
        ),
      ),
      const SizedBox(height: AppBrandSpacing.md),

      _stepNav(
        next: DarkPillButton(
          label: context.t.sellNext,
          variant: PillVariant.green,
          expand: true,
          onTap: () => _goToStep(3),
        ),
      ),
    ];
  }

  // ============================================================
  // ШАГ 3 — ФОТОГРАФИИ. Минимум один снимок обязателен.
  // ============================================================
  List<Widget> _buildStepPhotos() {
    return [
      _stepTitle(context.t.sellStepPhotos),

      // Кнопка добавления — ШИРОКАЯ ПОЛОСА во всю ширину карточки
      // с пунктирной рамкой, как на сайте. Прежний маленький квадрат
      // с иконкой слева читался как одна из миниатюр, а не как
      // единственное действие шага.
      //
      // Подписи «Фотографии (0/10)» здесь больше нет: заголовок шага
      // уже называется «Фотографии», и счётчик переехал в хвост строки
      // требований — ровно как на сайте.
      _AddPhotosButton(
        uploading: _uploading,
        enabled: _photoUrls.length < _maxPhotos,
        onTap: _pickAndUpload,
      ),
      const SizedBox(height: AppBrandSpacing.sm),

      // Требования к файлам и счётчик одной строкой.
      Text(
        '${context.t.sellPhotosHint} · ${_photoUrls.length} / $_maxPhotos',
        style: AppBrandText.small.copyWith(color: AppBrandColors.neutral50),
      ),

      // Миниатюры показываем только когда есть что показывать.
      if (_photoUrls.isNotEmpty) ...[
        const SizedBox(height: AppBrandSpacing.md),
        _PhotoStrip(
          urls: _photoUrls,
          onRemove: (i) => setState(() => _photoUrls.removeAt(i)),
          onMove: _movePhoto,
        ),
      ],
      const SizedBox(height: AppBrandSpacing.lg),

      _stepNav(
        next: DarkPillButton(
          label: context.t.sellNext,
          variant: PillVariant.green,
          expand: true,
          onTap: _goToContacts,
        ),
      ),
    ];
  }

  // ============================================================
  // ШАГ 4 — КОНТАКТЫ И ПУБЛИКАЦИЯ.
  // ============================================================
  List<Widget> _buildStepContact() {
    return [
      _stepTitle(context.t.sellStepContact),

      // ---------- Контактный телефон (обязательное) ----------
      // Подпись строкой над полем, как у остальных полей формы
      // и как «Номер телефона» на сайте.
      _fieldLabel(context.t.sellPhone),
      TextField(
        controller: _phoneCtrl,
        focusNode: _phoneFocus,
        keyboardType: TextInputType.phone,
        inputFormatters: [SerbianPhoneFormatter()],
        style: AppBrandText.body.copyWith(color: AppBrandColors.neutral100),
        decoration: const InputDecoration(
          hintText: '+381 6X XXX XXX',
          isDense: false,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppBrandSpacing.sm + 4,
            vertical: 12,
          ),
        ),
      ),
      const SizedBox(height: AppBrandSpacing.lg),

      // ---------- Публикация / сохранение ----------
      // Кнопки СТОЛБИКОМ, а не в строку: подпись «Опубликовать
      // объявление» длинная и в половине ширины обрезалась
      // многоточием. На сайте последний шаг устроен так же —
      // главное действие во всю ширину, «Назад» отдельной строкой
      // под ним.
      DarkPillButton(
        label: _publishing
            ? context.t.createSaving
            : (_isEdit
                ? context.t.createSaveAndSend
                : context.t.createPublish),
        variant: PillVariant.green,
        expand: true,
        onTap: _publishing ? null : _publish,
      ),
      const SizedBox(height: AppBrandSpacing.sm),
      DarkPillButton(
        label: context.t.sellBack,
        variant: PillVariant.outline,
        expand: true,
        onTap: () => _goToStep(3),
      ),
      const SizedBox(height: AppBrandSpacing.sm),
      Text(
        context.t.createAfterPublishNote,
        style: AppBrandText.caption.copyWith(color: AppBrandColors.neutral60),
        textAlign: TextAlign.center,
      ),
    ];
  }

  // Поле-пикер формы подачи — зеркало ListPicker сайта.
  //
  // Подпись стоит ОТДЕЛЬНОЙ СТРОКОЙ НАД рамкой, а не врезана в неё.
  // Раньше здесь был InputDecorator с labelText, то есть Material
  // floating label: подпись разрывала линию рамки сверху. На сайте
  // такого нет ни на одном поле — там <label> над контролом, а рамка
  // всегда замкнутая.
  //
  // Тема приложения (InputDecorationTheme) при этом НЕ трогается: она
  // общая для входа, фильтров и профиля, и менять её ради одной формы
  // значило бы переделать половину экранов заодно.
  Widget _pickerField({
    required String label,
    required String? value,
    required VoidCallback onTap,
    bool enabled = true,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppBrandRadius.controlAll,
          child: Container(
            height: AppTheme.controlHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: AppBrandSpacing.sm + 4, // px-3 сайта
            ),
            decoration: BoxDecoration(
              // Неактивное поле — заливка surfaceHover, как
              // «bg-surface-hover» у disabled-пикера сайта.
              color: enabled ? AppBrandColors.bg : AppBrandColors.surfaceHover,
              borderRadius: AppBrandRadius.controlAll,
              border: Border.all(color: AppBrandColors.neutral15),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? (hint ?? context.t.formAny),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppBrandText.body.copyWith(
                      // Незаполненное значение — подсказка neutral40,
                      // как «text-neutral-40» у пикера сайта.
                      color: value == null
                          ? AppBrandColors.neutral40
                          : AppBrandColors.neutral100,
                    ),
                  ),
                ),
                // Треугольник «▾» — тот же знак, что на сайте. Крупная
                // Material-шевронка (Icons.arrow_drop_down) выбивалась
                // из эталона по весу и размеру.
                Text(
                  '▾',
                  style: AppBrandText.body
                      .copyWith(color: AppBrandColors.neutral40),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Числовое поле: только цифры, сумма форматируется как «1 000».
  // Подпись — той же строкой над рамкой, что у пикера: на шаге «Детали»
  // числовые поля стоят вперемешку с пикерами, и разнобой был бы виден.
  Widget _numField(TextEditingController ctrl, String label, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: const [ThousandsFormatter()],
          style: AppBrandText.body.copyWith(color: AppBrandColors.neutral100),
          decoration: InputDecoration(
            // labelText НЕ задаём: подпись уже стоит над полем, и
            // Material нарисовал бы её вторично внутри рамки.
            hintText: hint,
            // isDense: false обязателен. В теме стоит true (плотные поля
            // фильтров), и вместе с обнулённым вертикальным паддингом
            // рамка схлопывалась вдвое ниже эталона: текст прижимался
            // к границам, а поле выглядело капсулой.
            isDense: false,
            // Высота набирается ПАДДИНГОМ, а не внешним SizedBox:
            // 12 + 12 + интерлиньяж 24 у текста 16px = 48, ровно
            // controlHeight. SizedBox растягивал только рамку, тогда
            // как содержимое внутри оставалось сжатым.
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppBrandSpacing.sm + 4,
              vertical: 12,
            ),
          ),
        ),
      ],
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
                hintText: widget.allowCustom ? context.t.formSearchOrEnter : context.t.formSearchHint,
                prefixIcon: const Icon(Icons.search),
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
                    title: Text(context.t.setCustom(trimmed)),
                    onTap: () => Navigator.pop(context, trimmed),
                  ),
                if (showCustom) const Divider(height: 1),
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

// Горизонтальная лента миниатюр фото + кнопка добавления
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.urls,
    required this.onRemove,
    required this.onMove,
  });

  final List<String> urls;
  final void Function(int) onRemove;

  /// Перестановка: (индекс, направление -1|1). Порядок определяет,
  /// какой кадр станет обложкой в каталоге, поэтому это не украшение,
  /// а единственный способ выбрать главное фото.
  final void Function(int index, int direction) onMove;

  @override
  Widget build(BuildContext context) {
    // Превью 4:3 — та же пропорция, что у карточки каталога и галереи:
    // человек сразу видит, каким кадр будет в выдаче.
    const previewH = 90.0;
    const previewW = previewH * 4 / 3;
    // Полоса со стрелками под кадром — как на сайте: «py-1.5» (6+6)
    // плюс интерлиньяж 20 у текста caption = 32. На 28 полоса была
    // ниже эталона, и стрелки в ней стояли теснее.
    const navH = 32.0;
    // Рамка карточки добавляет по пикселю сверху и снизу. Без этих
    // двух пикселей содержимое не помещалось в SizedBox, и Flutter
    // рисовал «BOTTOM OVERFLOWED BY 2.0 PIXELS» поверх стрелок.
    const borderH = 2.0;

    return SizedBox(
      height: previewH + navH + borderH,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppBrandSpacing.sm),
        itemBuilder: (context, i) {
          return Container(
            width: previewW,
            decoration: BoxDecoration(
              borderRadius: AppBrandRadius.controlAll,
              border: Border.all(color: AppBrandColors.neutral10),
            ),
            // clipBehavior обязателен: фотография и полоса стрелок
            // обязаны обрезаться по скруглению рамки.
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SizedBox(
                  height: previewH,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(urls[i], fit: BoxFit.cover),

                      // Метка обложки на ПЕРВОМ кадре: подсказка под
                      // кнопкой обещает «первая фотография — главная»,
                      // и метка показывает, какая именно сейчас первая.
                      if (i == 0)
                        Positioned(
                          left: AppBrandSpacing.xs,
                          top: AppBrandSpacing.xs,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppBrandColors.dark,
                              borderRadius: BorderRadius.circular(
                                AppBrandRadius.sm,
                              ),
                            ),
                            child: Text(
                              context.t.sellPhotosCover,
                              style: AppBrandText.small.copyWith(
                                color: Colors.white,
                                fontWeight: AppBrandFont.semibold,
                              ),
                            ),
                          ),
                        ),

                      // Удаление — КРАСНЫЙ круг, как на сайте: действие
                      // необратимое, и тёмный кружок не отличался от
                      // остальных элементов поверх кадра.
                      Positioned(
                        right: AppBrandSpacing.xs,
                        top: AppBrandSpacing.xs,
                        child: Semantics(
                          button: true,
                          label: context.t.sellPhotosRemove,
                          child: GestureDetector(
                            onTap: () => onRemove(i),
                            // Знак — текстовый «×» размера caption (14),
                            // как на сайте. Icons.close 16 рисуется
                            // толще и крупнее: на кружке 24px он
                            // занимал почти всю площадь.
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: AppBrandColors.red,
                              child: Text(
                                '×',
                                style: AppBrandText.caption.copyWith(
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Полоса перестановки. Крайние стрелки гасятся на
                // границах списка — как disabled-кнопки сайта.
                SizedBox(
                  height: navH,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppBrandColors.neutral10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MoveButton(
                            glyph: '←',
                            tooltip: context.t.sellPhotosMoveLeft,
                            enabled: i > 0,
                            onTap: () => onMove(i, -1),
                          ),
                        ),
                        const VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: AppBrandColors.neutral10,
                        ),
                        Expanded(
                          child: _MoveButton(
                            glyph: '→',
                            tooltip: context.t.sellPhotosMoveRight,
                            enabled: i < urls.length - 1,
                            onTap: () => onMove(i, 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Кнопка перестановки кадра. Неактивная не исчезает, а гаснет до
// neutral30: пропадающая кнопка сдвигала бы соседнюю под палец.
class _MoveButton extends StatelessWidget {
  const _MoveButton({
    required this.glyph,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  /// Символ стрелки («←» или «→»), а не IconData: на сайте это тоже
  /// текстовые знаки. Material-иконки arrow_back/arrow_forward рисуются
  /// заметно жирнее и с длинным хвостом — рядом с эталоном они читались
  /// как другой элемент.
  final String glyph;

  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Center(
            child: Text(
              glyph,
              style: AppBrandText.caption.copyWith(
                color: enabled
                    ? AppBrandColors.neutral60
                    : AppBrandColors.neutral30,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// СЕГМЕНТ «ПРОДАЮ / СДАЮ»
// ============================================================
// Активный сегмент — тёмная плашка бренда с белым текстом, неактивный —
// нейтральная рамка на белом. Ровно так на сайте выглядит выбранный
// вариант в паре кнопок: выбор читается по заливке, а не по оттенку.
//
// При открытии формы подсвечено «Продаю» — так же, как на сайте.
// Виджет при этом умеет показывать и состояние «ничего не выбрано»
// (value == null): оно остаётся рабочим, потому что поле nullable.
class _ListingTypeSegment extends StatelessWidget {
  const _ListingTypeSegment({
    required this.value,
    required this.labels,
    required this.onChanged,
  });

  /// null — тип ещё не выбран.
  final String? value;

  /// Ключ БД → подпись пользователю.
  final Map<String, String> labels;

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = labels.entries.toList();

    return Row(
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(width: AppBrandSpacing.sm),
          Expanded(
            child: _segment(
              label: entries[i].value,
              selected: value == entries[i].key,
              onTap: () => onChanged(entries[i].key),
            ),
          ),
        ],
      ],
    );
  }

  Widget _segment({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppBrandColors.dark : AppBrandColors.bg,
      borderRadius: AppBrandRadius.controlAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppBrandRadius.controlAll,
        child: Container(
          height: AppTheme.controlHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppBrandRadius.controlAll,
            border: Border.all(
              color: selected
                  ? AppBrandColors.dark
                  : AppBrandColors.neutral15,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // caption (14) = text-sm сайта. body (16) делал подписи
            // сегмента крупнее, чем на эталоне.
            style: AppBrandText.caption.copyWith(
              color: selected ? Colors.white : AppBrandColors.neutral100,
              fontWeight:
                  selected ? AppBrandFont.semibold : AppBrandFont.regular,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// РАМКА ФОРМЫ — зеркало components/ui/Card сайта.
// ============================================================
// Белая подложка, граница neutral10, радиус card и внутренний отступ.
// Тени НЕТ: на сайте карточки разделяются границей, а тень появляется
// только у кликабельной карточки объявления при наведении.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppBrandSpacing.md),
      decoration: BoxDecoration(
        color: AppBrandColors.bg,
        borderRadius: AppBrandRadius.cardAll,
        border: Border.all(color: AppBrandColors.neutral10),
      ),
      child: child,
    );
  }
}

// ============================================================
// КНОПКА «ДОБАВИТЬ ФОТОГРАФИИ» — зеркало <label> пикера сайта.
// ============================================================
// Широкая полоса во всю ширину карточки с ПУНКТИРНОЙ рамкой и текстом
// по центру. Пунктир здесь несёт смысл: он отличает «место, куда нужно
// положить файлы» от обычной кнопки действия — тот же приём, что
// на сайте.
//
// Во Flutter пунктирной рамки в BoxDecoration нет, поэтому она
// рисуется CustomPainter: заводить ради одной рамки пакет
// (dotted_border) было бы дороже, чем двадцать строк отрисовки.
class _AddPhotosButton extends StatelessWidget {
  const _AddPhotosButton({
    required this.uploading,
    required this.enabled,
    required this.onTap,
  });

  final bool uploading;

  /// false — достигнут лимит: кнопка гасится, но остаётся на месте,
  /// иначе исчезновение единственного действия выглядит как поломка.
  final bool enabled;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !uploading;

    return Opacity(
      opacity: active ? 1 : 0.4,
      child: InkWell(
        onTap: active ? onTap : null,
        borderRadius: AppBrandRadius.controlAll,
        child: CustomPaint(
          painter: const _DashedBorderPainter(
            color: AppBrandColors.neutral15,
            radius: AppBrandRadius.control,
          ),
          child: SizedBox(
            // Та же высота, что у полей формы: кнопка стоит в одном
            // столбце с ними и обязана держать общий ритм.
            height: AppTheme.controlHeight,
            width: double.infinity,
            child: Center(
              child: uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      context.t.sellPhotosAdd,
                      style: AppBrandText.body.copyWith(
                        color: AppBrandColors.neutral100,
                        fontWeight: AppBrandFont.medium,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// Пунктирная рамка со скруглением. Штрих и разрыв по 4 логических
// пикселя — тот же ритм, что даёт CSS «border-dashed» в браузере.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    // Путь режем на отрезки: PathMetric даёт длину контура, и по нему
    // выбираются куски «штрих — пропуск» до самого конца.
    const dash = 4.0;
    const gap = 4.0;
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

// ============================================================
// AUTO.RS — Экран «Подать объявление».
// Форма характеристик + загрузка фото в Storage + RPC create_car_v2.
// Объявление создаётся со статусом moderation (одобряет админ).
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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

  // Контроллеры полей
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  // Тип объявления
  String _listingType = 'sale'; // 'sale' | 'rent' | 'both'

  // Загруженные публичные URL фото (по порядку)
  final List<String> _photoUrls = [];

  bool _uploading = false;
  bool _publishing = false;

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _mileageCtrl.dispose();
    _priceCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Выбор фото из галереи и загрузка в Storage
  Future<void> _pickAndUpload() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      // index = текущая длина списка (порядок сохранится в car_images)
      final url = await _carsRepo.uploadCarImage(
        tempCarUuid: _tempCarUuid,
        index: _photoUrls.length,
        bytes: bytes,
      );
      setState(() => _photoUrls.add(url));
    } catch (e) {
      _snack('Не удалось загрузить фото: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // Публикация объявления
  Future<void> _publish() async {
    // Гость — на вход
    if (_auth.currentUser == null) {
      _snack('Войдите, чтобы подать объявление');
      return;
    }

    // Парсинг числовых полей
    final year = int.tryParse(_yearCtrl.text.trim());
    final price = double.tryParse(_priceCtrl.text.trim().replaceAll(',', '.'));
    final mileage = int.tryParse(_mileageCtrl.text.trim());

    // Валидация (общая утилита)
    final err = validateCarForm(
      _brandCtrl.text.trim(),
      _modelCtrl.text.trim(),
      year,
      price,
      _cityCtrl.text.trim(),
      _photoUrls,
    );
    if (err != null) {
      _snack(err);
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
        brand: _brandCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        year: year!,
        mileage: mileage,
        price: price!,
        city: _cityCtrl.text.trim(),
        photoUrls: _photoUrls,
      );
      _snack('Объявление отправлено на модерацию');
      // Возвращаемся назад (в каталог/список)
      if (mounted) {
        // Небольшая пауза, чтобы снекбар успел показаться
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

            // ---------- Характеристики ----------
            _field(_brandCtrl, 'Марка'),
            _field(_modelCtrl, 'Модель'),
            _field(_yearCtrl, 'Год выпуска', number: true),
            _field(_mileageCtrl, 'Пробег, км (необязательно)', number: true),
            _field(
              _priceCtrl,
              _listingType == 'rent'
                  ? 'Цена аренды в сутки, EUR'
                  : 'Цена, EUR',
              number: true,
            ),
            _field(_cityCtrl, 'Город'),

            const SizedBox(height: 16),

            // ---------- Фото ----------
            Text('Фотографии', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _PhotoStrip(
              urls: _photoUrls,
              uploading: _uploading,
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

  // Поле формы
  Widget _field(TextEditingController ctrl, String label,
      {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

// Горизонтальная лента миниатюр фото + кнопка добавления
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.urls,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> urls;
  final bool uploading;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Кнопка добавления
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

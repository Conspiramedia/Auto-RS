// ============================================================
// AUTO.RS — Тесты словаря пошаговой подачи.
// ============================================================
// Ключи sell* — зеркало ключей sell_* сайта (lib/i18n.ts). Экран подачи
// требует Supabase в initState и в виджет-тесте не поднимается, поэтому
// проверяем сам словарь: непустые строки в ОБЕИХ локалях и то, что
// подписи сегмента отличаются от подписей фильтров.
// ============================================================

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_rs/core/config/app_constants.dart';
import 'package:auto_rs/core/i18n/app_strings.dart';

void main() {
  // Обе локали проверяются одинаково: сербский — язык по умолчанию,
  // и пропуск ключа в нём заметен позже всего.
  final locales = <String, AppStrings>{
    'ru': stringsFor(const Locale('ru')),
    'sr': stringsFor(const Locale('sr')),
  };

  locales.forEach((name, t) {
    group('Локаль $name', () {
      test('Ключи шагов подачи заполнены', () {
        final values = <String, String>{
          'sellStep': t.sellStep,
          'sellNext': t.sellNext,
          'sellBack': t.sellBack,
          'sellStepCar': t.sellStepCar,
          'sellStepDetails': t.sellStepDetails,
          'sellStepPhotos': t.sellStepPhotos,
          'sellStepContact': t.sellStepContact,
          'sellTypeSale': t.sellTypeSale,
          'sellTypeRent': t.sellTypeRent,
          'sellErrPhotosRequired': t.sellErrPhotosRequired,
          'sellPhone': t.sellPhone,
          'sellPhotosCover': t.sellPhotosCover,
          'sellPhotosMoveLeft': t.sellPhotosMoveLeft,
          'sellPhotosMoveRight': t.sellPhotosMoveRight,
          'sellPhotosRemove': t.sellPhotosRemove,
          'sellTitle': t.sellTitle,
          'sellSubtitle': t.sellSubtitle,
          'pickerModelNoBrand': t.pickerModelNoBrand,
          'commonClose': t.commonClose,
          'commonBack': t.commonBack,
        };

        values.forEach((key, value) {
          expect(value.trim(), isNotEmpty, reason: '$key пуст в локали $name');
        });
      });

      test('Подзаголовок дословный — с упоминанием установки', () {
        // Текст обязан совпадать с sell_subtitle сайта целиком. Хвост
        // «без установки приложения» однажды был обрезан как якобы
        // лишний внутри приложения — тексты в обоих клиентах должны
        // быть одинаковыми, и проверка держит это.
        final tail = name == 'ru' ? 'без установки' : 'bez instaliranja';
        expect(t.sellSubtitle, contains(tail));
        expect(t.sellSubtitle, contains('—'));
      });

      test('Подпись публикации — полная, как sell_submit сайта', () {
        // Сайт: «Опубликовать объявление» / «Objavi oglas». Короткое
        // «Опубликовать» было на слово короче эталона.
        final tail = name == 'ru' ? 'объявление' : 'oglas';
        expect(t.createPublish, contains(tail));
      });

      test('Заглушка пустого поля — «Все», как filter_any сайта', () {
        // Одно слово и в фильтрах, и в подаче: на сайте оба экрана
        // берут filter_any. Прежнее «Не важно» / «Nije važno» звучало
        // как ответ на вопрос, а не как состояние поля.
        final expected = name == 'ru' ? 'Все' : 'Sve';
        expect(t.formAny, expected);
      });

      test('Подписи шага «Детали» короткие — под три колонки', () {
        // Кузов / Коробка / Топливо стоят в ряд по три, каждая колонка
        // шириной в треть экрана. Длинные подписи вроде «Коробка
        // передач» там обрезались бы многоточием.
        for (final label in [t.formBodyType, t.formTransmission, t.carFuel]) {
          expect(
            label.length,
            lessThanOrEqualTo(12),
            reason: '«$label» не помещается в колонку шага «Детали»',
          );
        }
      });

      test('Цена в подаче подписана символом валюты', () {
        // На сайте это «Цена продажи, €» — знак, а не код «EUR».
        expect(t.createPriceLabel, contains('€'));
        expect(t.formRentPrice, contains('€'));
      });

      test('Заглушка цены в форме — законченная фраза', () {
        // В форме поле уже подписано «Цена продажи», и заглушка звучит
        // как «Цена договорная» — так на сайте. Общий priceNegotiable
        // при этом остаётся коротким: он стоит ВМЕСТО суммы в каталоге,
        // где длинный вариант дал бы «Цена: Цена договорная».
        expect(t.sellPriceNegotiableHint.length,
            greaterThan(t.priceNegotiable.length));
        if (name == 'ru') {
          expect(t.sellPriceNegotiableHint, 'Цена договорная');
          expect(t.priceNegotiable, 'Договорная');
        }
      });

      test('Строка требований к фото заполнена', () {
        // Форматы, предел размера и объяснение про главный кадр.
        // Раньше в приложении этой строки не было вовсе, и продавец
        // узнавал о требованиях только после отказа при загрузке.
        expect(t.sellPhotosHint, contains('JPG'));
        expect(t.sellPhotosHint, contains('10'));
        expect(t.sellPhotosAdd.trim(), isNotEmpty);
      });

      test('Подпись телефона в форме полнее, чем на экране входа', () {
        // Сайт: «Номер телефона». Короткое «Телефон» осталось у
        // LoginScreen, где рядом нет других полей.
        expect(t.sellPhone, isNot(equals(t.loginPhoneLabel)));
        expect(t.sellPhone.length, greaterThan(t.loginPhoneLabel.length));
      });

      test('Подписи сегмента отличаются от подписей фильтров', () {
        // В подаче вопрос от первого лица («Продаю»), в фильтрах —
        // категория выдачи («Продажа»). Совпадение означало бы, что
        // экран снова взял чужие подписи.
        expect(t.sellTypeSale, isNot(equals(t.filterSale)));
        expect(t.sellTypeRent, isNot(equals(t.filterRent)));
      });
    });
  });

  test('Лимит фото — один на всё приложение', () {
    // Раньше форма подачи держала своё число 10 при
    // AppConstants.maxCarImages = 15: два разных лимита в одном
    // приложении. Теперь константа одна, и она же равна MAX_PHOTOS
    // формы сайта.
    expect(AppConstants.maxCarImages, 10);
  });
}

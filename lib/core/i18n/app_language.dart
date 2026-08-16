// ============================================================
// AUTO.RS — Язык интерфейса: хранение и определение.
//
// Три состояния выбора:
//   AppLanguage.system — следовать языку телефона (значение по умолчанию);
//   AppLanguage.sr     — сербский принудительно;
//   AppLanguage.ru     — русский принудительно.
//
// Зачем нужен ручной выбор поверх автоопределения: в Сербии много
// русскоязычных пользователей с телефоном на сербском/английском — система
// вернёт 'sr', а человеку нужен русский (и наоборот). Автоопределение лишь
// угадывает ПЕРВЫЙ запуск, дальше решает пользователь.
//
// Хранилище — SharedPreferences (локально, переживает перезапуск). Синхронный
// доступ через синглтон с in-memory кэшем: UI читает current без await.
// На будущее: когда добавим колонку profiles.language, сюда же дописывается
// синхронизация с сервером (нужна для пушей/писем на языке пользователя) —
// публичный API сервиса при этом не меняется. [[language-plan]]
// ============================================================

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Вариант выбора языка в настройках профиля.
enum AppLanguage {
  system, // как в телефоне
  sr,     // српски
  ru;     // русский

  // Значение для хранения на диске/сервере.
  String get storageValue => name;

  // Разбор сохранённого значения; мусор и null → system.
  static AppLanguage fromStorage(String? value) {
    switch (value) {
      case 'sr':
        return AppLanguage.sr;
      case 'ru':
        return AppLanguage.ru;
      default:
        return AppLanguage.system;
    }
  }

  // Подпись пункта в списке выбора. Названия языков пишем на самих языках —
  // так их узнаёт носитель, даже если сейчас включён чужой интерфейс.
  String get label {
    switch (this) {
      case AppLanguage.system:
        return 'Как в телефоне';
      case AppLanguage.sr:
        return 'Српски';
      case AppLanguage.ru:
        return 'Русский';
    }
  }
}

// Поддерживаемые языки интерфейса. Сербский — основной для рынка Сербии,
// поэтому он же служит запасным при незнакомой системной локали.
const Locale kLocaleSr = Locale('sr');
const Locale kLocaleRu = Locale('ru');
const List<Locale> kSupportedLocales = [kLocaleSr, kLocaleRu];

class AppLanguageService extends ChangeNotifier {
  AppLanguageService._();
  static final AppLanguageService instance = AppLanguageService._();

  static const _prefsKey = 'app_language';

  AppLanguage _selection = AppLanguage.system;
  bool _loaded = false;

  // Текущий выбор пользователя (не итоговый язык — см. resolveLocale).
  AppLanguage get selection => _selection;
  bool get isLoaded => _loaded;

  // Читаем сохранённый выбор с диска. Вызывается один раз в main() до runApp,
  // чтобы первый кадр отрисовался сразу на нужном языке (без мигания).
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _selection = AppLanguage.fromStorage(prefs.getString(_prefsKey));
    } catch (_) {
      // Диск недоступен — остаёмся на system, приложение не падает.
    } finally {
      _loaded = true;
    }
  }

  // Смена языка из настроек профиля: обновляем кэш, оповещаем UI (перерисовка
  // MaterialApp), затем пишем на диск. Порядок важен — интерфейс должен
  // переключиться мгновенно, не дожидаясь записи.
  Future<void> setSelection(AppLanguage value) async {
    if (_selection == value) return;
    _selection = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, value.storageValue);
    } catch (_) {
      // Не сохранилось — выбор действует до перезапуска приложения.
    }
  }

  // Итоговая локаль для MaterialApp.
  // null = «отдать решение Flutter», который сам сопоставит системные локали
  // телефона со списком supportedLocales через localeResolutionCallback ниже.
  Locale? get materialLocale {
    switch (_selection) {
      case AppLanguage.system:
        return null;
      case AppLanguage.sr:
        return kLocaleSr;
      case AppLanguage.ru:
        return kLocaleRu;
    }
  }

  // Какой язык реально показан сейчас (для подписи в настройках при выборе
  // «Как в телефоне»). deviceLocales — список локалей устройства по убыванию
  // приоритета: WidgetsBinding.instance.platformDispatcher.locales.
  static Locale resolveLocale(
    AppLanguage selection,
    List<Locale> deviceLocales,
  ) {
    switch (selection) {
      case AppLanguage.sr:
        return kLocaleSr;
      case AppLanguage.ru:
        return kLocaleRu;
      case AppLanguage.system:
        // Идём по языкам телефона в порядке приоритета и берём первый,
        // который умеем показывать. Сравниваем ТОЛЬКО код языка: 'ru_RU',
        // 'sr_Latn_RS' и т.п. должны совпасть с 'ru' / 'sr'.
        for (final locale in deviceLocales) {
          for (final supported in kSupportedLocales) {
            if (locale.languageCode == supported.languageCode) return supported;
          }
        }
        // Ни один язык телефона не поддержан (например, английский) —
        // показываем сербский как язык рынка.
        return kLocaleSr;
    }
  }
}

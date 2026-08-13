// ============================================================
// AUTO.RS — Репозиторий «просмотренных объявлений».
// Хранит множество id открытых карточек ЛОКАЛЬНО (SharedPreferences),
// чтобы помечать их плашкой «Просмотрено» в каталоге.
//
// Синглтон с in-memory кэшем: грид читает isViewed синхронно (без await
// на каждую карточку), а запись параллельно сохраняется на диск.
//
// На будущее: при переходе на серверное хранилище (таблица car_views в
// Supabase) достаточно заменить реализацию load()/markViewed() — публичный
// API репозитория остаётся прежним, UI править не нужно. [[phone-reveal-goal]]
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';

class ViewedCarsRepository {
  // Единственный экземпляр — общий кэш на всё приложение.
  ViewedCarsRepository._();
  static final ViewedCarsRepository instance = ViewedCarsRepository._();

  // Ключ в SharedPreferences (список id через запятую хранится как List<String>).
  static const _prefsKey = 'viewed_car_ids';

  // In-memory множество просмотренных id. Заполняется при первом load().
  final Set<String> _ids = {};
  bool _loaded = false;

  // Загрузка сохранённых id с диска (однократно при старте каталога).
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsKey) ?? const [];
      _ids
        ..clear()
        ..addAll(saved);
    } catch (_) {
      // Диск недоступен — работаем с пустым множеством, не падаем.
    } finally {
      _loaded = true;
    }
  }

  // Синхронная проверка «просмотрено» — для рендера карточек в гриде.
  bool isViewed(String carId) => _ids.contains(carId);

  // Пометить объявление просмотренным. Возвращает true, если это НОВЫЙ
  // просмотр (id ещё не был отмечен) — вызывающий может по этому обновить UI.
  Future<bool> markViewed(String carId) async {
    if (_ids.contains(carId)) return false; // уже просмотрено — ничего не делаем
    _ids.add(carId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _ids.toList());
    } catch (_) {
      // Не удалось сохранить — id останется хотя бы в памяти на эту сессию.
    }
    return true;
  }
}

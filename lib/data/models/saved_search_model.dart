// ============================================================
// AUTO.RS — Модель SavedSearchModel (зеркало public.saved_searches).
//
// Сохранённый поиск = подписка на появление новых объявлений под заданные
// фильтры. Создаётся из онбординга и кнопки «Сообщить, когда появится».
//
// Дубли невозможны: сервер считает хэш канонизированных фильтров, поэтому
// повторное сохранение того же набора лишь реактивирует существующую
// подписку. Нормализация (кириллица/латиница) учтена в хэше — «BMW» и «БМВ»
// это одна подписка.
// ============================================================

class SavedSearchModel {
  final String id;
  final Map<String, dynamic> filters; // brand, model, city, fuel, price_*, year_*
  final String? title;                // подпись для списка подписок
  final bool active;                  // выключенная не рассылает пуши
  final DateTime createdAt;

  const SavedSearchModel({
    required this.id,
    required this.filters,
    this.title,
    this.active = true,
    required this.createdAt,
  });

  // Читаемая подпись подписки: сохранённый заголовок, а если его нет —
  // собираем из самих фильтров («BMW · Београд · до 10000»).
  String get displayTitle {
    final saved = title?.trim();
    if (saved != null && saved.isNotEmpty) return saved;

    final parts = <String>[];
    for (final key in const ['brand', 'model', 'city', 'fuel']) {
      final value = filters[key]?.toString().trim();
      if (value != null && value.isNotEmpty) parts.add(value);
    }

    final from = filters['price_from']?.toString();
    final to = filters['price_to']?.toString();
    if (from != null && to != null) {
      parts.add('$from–$to');
    } else if (from != null) {
      parts.add('от $from');
    } else if (to != null) {
      parts.add('до $to');
    }

    final yearFrom = filters['year_from']?.toString();
    final yearTo = filters['year_to']?.toString();
    if (yearFrom != null || yearTo != null) {
      parts.add('${yearFrom ?? ''}–${yearTo ?? ''} г.');
    }

    // Пустая подписка сервером не сохраняется, но подстраховываемся.
    return parts.isEmpty ? 'Все объявления' : parts.join(' · ');
  }

  factory SavedSearchModel.fromMap(Map<String, dynamic> map) {
    return SavedSearchModel(
      id: map['id'] as String,
      filters: (map['filters'] as Map?)?.cast<String, dynamic>() ?? const {},
      title: map['title'] as String?,
      active: map['active'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

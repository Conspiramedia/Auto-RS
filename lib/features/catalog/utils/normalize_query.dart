// ============================================================
// AUTO.RS — Custom Function для FlutterFlow: normalizeQuery
// ============================================================
// Превращает пустую/пробельную строку поиска в null, чтобы RPC
// search_cars_advanced не применял текстовый фильтр впустую.
//
// -----------------------------------------------------------------
// НАСТРОЙКА ВО FLUTTERFLOW (Custom Function):
//   Имя: normalizeQuery
//   Return Type: String (Nullable = ДА)
//   Arguments: query : String (Nullable)
// -----------------------------------------------------------------

String? normalizeQuery(String? query) {
  if (query == null) return null;
  final trimmed = query.trim();
  return trimmed.isEmpty ? null : trimmed;
}

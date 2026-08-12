// ============================================================
// AUTO.RS — Custom Function для FlutterFlow: normalizeRadiusKm
// ============================================================
// Предобработка радиуса перед передачей в RPC search_cars_advanced.
// Задача: превратить "выключенное" значение слайдера (0 км) в null,
// чтобы БД ОТКЛЮЧИЛА гео-фильтр, а не искала в радиусе 0 метров
// (что вернуло бы пустой результат).
//
// -----------------------------------------------------------------
// НАСТРОЙКА ВО FLUTTERFLOW (Custom Function):
//   Имя: normalizeRadiusKm
//   Return Type: double (Nullable = ДА)
//   Arguments:
//     radiusKm : double  (Nullable)  — сырое значение слайдера
//     hasCoords: bool                — определены ли координаты пользователя
//
//   Возврат:
//     null   → гео-фильтр в RPC выключен (нет координат ИЛИ радиус <= 0);
//     double → радиус в км для передачи в p_radius_km.
// -----------------------------------------------------------------

double? normalizeRadiusKm(double? radiusKm, bool hasCoords) {
  // Без координат гео-фильтр невозможен — всегда null
  if (!hasCoords) return null;

  // Радиус не задан или "выключен" (0 и меньше) — гео-фильтр отключаем
  if (radiusKm == null || radiusKm <= 0) return null;

  return radiusKm;
}

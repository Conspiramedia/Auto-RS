// ============================================================
// AUTO.RS — Custom Function для FlutterFlow: canUserBookCar
// ============================================================
// Быстрый кондишен: разрешено ли пользователю бронировать аренду.
// Разрешено ТОЛЬКО при пройденной верификации (verified).
//
// -----------------------------------------------------------------
// НАСТРОЙКА ВО FLUTTERFLOW (Custom Function):
//   Имя: canUserBookCar
//   Return Type: bool (не nullable)
//   Arguments:
//     verificationStatus : String (Nullable)
//       — значение profiles.verification_status текущего пользователя.
//
//   Возврат:
//     true  → статус 'verified', бронирование разрешено;
//     false → любой другой статус (unverified/pending/rejected/null).
// -----------------------------------------------------------------

bool canUserBookCar(String? verificationStatus) {
  // Бронировать может только верифицированный пользователь.
  // Любой иной статус (в т.ч. null — профиль не загружен) → запрет.
  return verificationStatus == 'verified';
}

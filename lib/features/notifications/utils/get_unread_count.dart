// ============================================================
// AUTO.RS — Custom Function для FlutterFlow: getUnreadNotificationsCount
// ============================================================
// Считает количество непрочитанных уведомлений из переданного списка —
// для цифры на бэйдже колокольчика в навигации.
//
// -----------------------------------------------------------------
// НАСТРОЙКА ВО FLUTTERFLOW (Custom Function):
//   Имя: getUnreadNotificationsCount
//   Return Type: int (не nullable)
//   Arguments:
//     notifications : List<dynamic>  (список строк notifications из Query/Stream)
//
//   Возврат: число элементов, где is_read == false.
//
// Примечание: во FlutterFlow элементы списка из Supabase приходят как
// Map/JSON. Функция читает поле 'is_read' у каждого элемента.
// -----------------------------------------------------------------

int getUnreadNotificationsCount(List<dynamic>? notifications) {
  if (notifications == null || notifications.isEmpty) {
    return 0;
  }

  int count = 0;
  for (final item in notifications) {
    // Элемент может быть Map (JSON-строка из Supabase)
    if (item is Map) {
      final isRead = item['is_read'];
      // Непрочитано, если is_read == false (или отсутствует/не bool → считаем непрочитанным)
      if (isRead == false || isRead == null) {
        count++;
      }
    }
  }
  return count;
}

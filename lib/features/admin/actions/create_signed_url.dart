// ============================================================
// AUTO.RS — Custom Action для FlutterFlow: createSignedDocUrl
// ============================================================
// Генерирует временную подписанную ссылку (Signed URL) на приватный
// документ из бакета user-documents. Нужна, т.к. бакет private (0019) —
// прямых ссылок нет, показать паспорт/права можно только по signed URL.
//
// -----------------------------------------------------------------
// НАСТРОЙКА ВО FLUTTERFLOW (Custom Action):
//   Имя: createSignedDocUrl
//   Return Type: String (Nullable = ДА)  // null, если путь пуст/ошибка
//   Arguments:
//     path         : String   (путь в бакете, напр. "<uid>/passport_xxx.jpg")
//     expiresInSec : int       (TTL ссылки в секундах, напр. 300)
//
// Зависимость: supabase_flutter (уже в проекте).
// Вызывать только у админа — доступ к чтению чужих документов даёт
// RLS-политика user_docs_select_owner_or_admin (0019, ветка is_admin()).
// -----------------------------------------------------------------

import 'package:supabase_flutter/supabase_flutter.dart';

Future<String?> createSignedDocUrl(String? path, int expiresInSec) async {
  // Пустой путь (документ не загружен) — ссылки нет
  if (path == null || path.trim().isEmpty) {
    return null;
  }

  try {
    // createSignedUrl возвращает временную ссылку, действующую expiresInSec секунд
    final signedUrl = await Supabase.instance.client.storage
        .from('user-documents')
        .createSignedUrl(path, expiresInSec);
    return signedUrl;
  } catch (e) {
    // При ошибке (нет прав/файла) возвращаем null — UI покажет плейсхолдер
    return null;
  }
}

// ============================================================
// AUTO.RS — Сервис согласия с политикой (локальная фиксация).
//
// Зачем локально: аккаунт создаётся по SMS-коду только в момент
// «Опубликовать», а форму объявления заполняет ещё гость. Отдельной
// таблицы/колонки в БД под согласие пока нет, поэтому факт принятия
// храним на устройстве через shared_preferences — сохраняем ВЕРСИЮ
// принятой политики. Согласие действительно, если сохранённая версия
// совпадает с текущей (kPolicyVersion): подняли версию текста —
// согласие запросится заново.
//
// Ключ включает идентификатор пользователя (uid авторизованного или
// 'guest'), чтобы согласие одного человека не «переносилось» на другого
// на общем устройстве.
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';

import 'policy_content.dart';

class ConsentService {
  ConsentService._();

  /// Единственный экземпляр (сервис без состояния — храним всё в prefs).
  static final ConsentService instance = ConsentService._();

  // Префикс ключа; полный ключ — «policy_accepted_version:<uid|guest>».
  static const _keyPrefix = 'policy_accepted_version';

  String _key(String? userId) =>
      '$_keyPrefix:${userId == null || userId.isEmpty ? 'guest' : userId}';

  /// Принята ли ТЕКУЩАЯ версия политики данным пользователем (или гостем).
  Future<bool> hasAcceptedCurrent(String? userId) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_key(userId)) == kPolicyVersion;
  }

  /// Зафиксировать согласие с текущей версией политики.
  Future<void> accept(String? userId) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key(userId), kPolicyVersion);
  }

  /// Перенести гостевое согласие на аккаунт после входа.
  ///
  /// Согласие даётся ещё до создания аккаунта (на экране SMS-входа под
  /// ключом 'guest'). После успешного входа копируем его на реальный uid,
  /// чтобы политику не спрашивали повторно. Гостевую запись затем чистим.
  Future<void> migrateGuestToUser(String userId) async {
    if (userId.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    final guestValue = sp.getString(_key(null)); // ключ гостя
    if (guestValue == kPolicyVersion) {
      await sp.setString(_key(userId), kPolicyVersion);
    }
    await sp.remove(_key(null)); // гостевую запись больше не держим
  }
}

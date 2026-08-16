// ============================================================
// AUTO.RS — Репозиторий аутентификации.
// Вход ТОЛЬКО по номеру телефона + одноразовый код из SMS (OTP).
// Пароля и email-регистрации нет: аккаунт создаётся Supabase Auth при
// первом подтверждении номера. Телефон = идентификатор пользователя.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

// Исключение: суточный лимит отправок SMS-кода на номер исчерпан.
// Ловится на экране входа, чтобы показать пользователю понятный текст.
class OtpQuotaExceeded implements Exception {
  const OtpQuotaExceeded(this.limit);
  final int? limit; // лимит в сутки (для текста сообщения), может быть null

  @override
  String toString() {
    final n = limit != null ? '$limit' : 'дневной';
    return 'Превышен лимит запросов кода ($n в сутки). '
        'Попробуйте завтра или войдите позже.';
  }
}

class AuthRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // Текущий пользователь (null, если не авторизован)
  User? get currentUser => _client.auth.currentUser;

  // Признак авторизации
  bool get isLoggedIn => currentUser != null;

  // Поток изменений состояния авторизации — для реактивного роутера.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ----------------------------------------------------------
  // Шаг 1. Отправка кода на телефон.
  // phone — в международном формате E.164 (например «+3816XXXXXXXX»).
  // shouldCreateUser: true — если номера ещё нет, Supabase создаст аккаунт
  // при верной проверке кода; если номер уже есть — войдёт в существующий.
  //
  // Перед отправкой проверяем суточную квоту на номер (экономия на SMS):
  // если лимит исчерпан — SMS НЕ отправляется, бросаем OtpQuotaExceeded.
  // ----------------------------------------------------------
  Future<void> sendOtp(String phone) async {
    await _ensureOtpQuota(phone);
    await _client.auth.signInWithOtp(
      phone: phone,
      channel: OtpChannel.sms,
    );
  }

  // Проверка суточного лимита отправок OTP через RPC на бэкенде.
  // Успех разрешённой отправки RPC сам фиксирует в журнале, поэтому
  // вызывать её нужно РОВНО один раз перед каждой реальной отправкой.
  Future<void> _ensureOtpQuota(String phone) async {
    final res = await _client.rpc(
      'rpc_check_otp_quota',
      params: {'p_phone': phone},
    );
    // RPC возвращает json: { allowed, used, limit, remaining }.
    final allowed = (res is Map) ? res['allowed'] == true : false;
    if (!allowed) {
      final limit = (res is Map) ? res['limit'] : null;
      throw OtpQuotaExceeded(limit is int ? limit : null);
    }
  }

  // ----------------------------------------------------------
  // Шаг 2. Проверка кода из SMS.
  // При успехе Supabase сам сохраняет сессию на диск (persistSession),
  // поэтому повторный вход не потребуется, пока сессия жива.
  // Возвращает AuthResponse (session/user) — вызывающий может проверить успех.
  // ----------------------------------------------------------
  Future<AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }

  // ----------------------------------------------------------
  // Повторная отправка кода (кнопка «Отправить снова» с таймером).
  // Тоже расходует SMS — поэтому тоже учитывается в суточной квоте.
  // ----------------------------------------------------------
  Future<void> resendOtp(String phone) async {
    await _ensureOtpQuota(phone);
    await _client.auth.resend(phone: phone, type: OtpType.sms);
  }

  // ----------------------------------------------------------
  // Выход. Локальная сессия стирается — при следующем входе снова код.
  // ----------------------------------------------------------
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

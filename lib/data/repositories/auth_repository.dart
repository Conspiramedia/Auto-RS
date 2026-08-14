// ============================================================
// AUTO.RS — Репозиторий аутентификации.
// Вход ТОЛЬКО по номеру телефона + одноразовый код из SMS (OTP).
// Пароля и email-регистрации нет: аккаунт создаётся Supabase Auth при
// первом подтверждении номера. Телефон = идентификатор пользователя.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

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
  // ----------------------------------------------------------
  Future<void> sendOtp(String phone) async {
    await _client.auth.signInWithOtp(
      phone: phone,
      channel: OtpChannel.sms,
    );
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
  // ----------------------------------------------------------
  Future<void> resendOtp(String phone) async {
    await _client.auth.resend(phone: phone, type: OtpType.sms);
  }

  // ----------------------------------------------------------
  // Выход. Локальная сессия стирается — при следующем входе снова код.
  // ----------------------------------------------------------
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

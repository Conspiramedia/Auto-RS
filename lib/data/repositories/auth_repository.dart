// ============================================================
// AUTO.RS — Репозиторий аутентификации.
// Обёртка над Supabase Auth: вход, регистрация, выход, текущий пользователь.
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
  // Вход по email/паролю.
  // ----------------------------------------------------------
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  // ----------------------------------------------------------
  // Регистрация. full_name пробрасываем в user metadata — триггер
  // handle_new_user (0002) создаст профиль с этим именем.
  // ----------------------------------------------------------
  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
  }

  // ----------------------------------------------------------
  // Выход.
  // ----------------------------------------------------------
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

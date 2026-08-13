// ============================================================
// AUTO.RS — Экран авторизации (вход / регистрация / гость).
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/widgets/pill_back_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthRepository();

  // Режим: false — вход, true — регистрация
  bool _isRegister = false;
  bool _loading = false;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // Показ сообщения об ошибке/успехе
  void _snack(String msg) {
    if (!mounted) return;
    showAppSnack(context, msg);
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    // Базовая валидация
    if (email.isEmpty || pass.isEmpty) {
      _snack('Введите email и пароль');
      return;
    }
    if (_isRegister) {
      if (pass != _confirmCtrl.text) {
        _snack('Пароли не совпадают');
        return;
      }
      if (pass.length < 6) {
        _snack('Пароль должен быть не короче 6 символов');
        return;
      }
    }

    setState(() => _loading = true);
    try {
      if (_isRegister) {
        await _auth.signUp(
          email: email,
          password: pass,
          fullName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        );
        _snack('Регистрация успешна');
      } else {
        await _auth.signIn(email: email, password: pass);
      }
      // Успех: роутер сам уведёт на /catalog (redirect по authStateChanges)
      if (mounted) context.go('/catalog');
    } catch (e) {
      // Текст ошибки Supabase Auth (email занят, неверный пароль и т.п.)
      _snack(_humanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Приводим технические ошибки к понятному виду
  String _humanError(Object e) {
    final s = e.toString();
    if (s.contains('already registered')) return 'Этот email уже зарегистрирован';
    if (s.contains('Invalid login')) return 'Неверный email или пароль';
    if (s.contains('at least 6')) return 'Пароль должен быть не короче 6 символов';
    return humanizeError(e);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const PillBackButton(), title: const Text('Auto.RS')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Логотип приложения
                Image.asset(
                  'assets/images/logo.png',
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  _isRegister ? 'Регистрация' : 'Вход',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),

                // Имя — только при регистрации
                if (_isRegister) ...[
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Имя',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Подтверждение пароля — только при регистрации
                if (_isRegister) ...[
                  TextField(
                    controller: _confirmCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Повторите пароль',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                const SizedBox(height: 12),

                // Кнопка отправки
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isRegister ? 'Зарегистрироваться' : 'Войти'),
                  ),
                ),
                const SizedBox(height: 8),

                // Переключатель вход ↔ регистрация
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _isRegister = !_isRegister),
                  child: Text(_isRegister
                      ? 'Уже есть аккаунт? Войти'
                      : 'Нет аккаунта? Зарегистрироваться'),
                ),

                const Divider(height: 32),

                // Гостевой режим — сразу в каталог
                TextButton(
                  onPressed: _loading ? null : () => context.go('/catalog'),
                  child: const Text('Продолжить как гость'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

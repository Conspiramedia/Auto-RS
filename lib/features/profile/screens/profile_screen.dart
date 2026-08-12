// ============================================================
// AUTO.RS — Экран профиля (минимальный): email + выход.
// Полный профиль (KYC, баланс, транзакции) добавим следующим этапом.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/auth_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthRepository();
  bool _loading = false;

  Future<void> _signOut() async {
    setState(() => _loading = true);
    try {
      await _auth.signOut();
      // Роутер по authStateChanges уведёт на /login при попытке открыть профиль;
      // явно переходим на каталог (гостевой доступ).
      if (mounted) context.go('/catalog');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
            const SizedBox(height: 16),
            Text(
              user?.email ?? 'Гость',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            if (user != null)
              FilledButton.tonal(
                onPressed: _loading ? null : _signOut,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Выйти из аккаунта'),
              )
            else
              FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('Войти'),
              ),
          ],
        ),
      ),
    );
  }
}

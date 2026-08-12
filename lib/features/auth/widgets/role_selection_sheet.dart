// ============================================================
// AUTO.RS — Bottom Sheet выбора роли (онбординг). Две карточки:
// «Ищу машину» (customer) / «Сдаю машину» (vendor). Записывает роль
// через ProfileRepository.selectRole и закрывается.
// Показывается при первом входе (role_selected == false).
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/repositories/profile_repository.dart';

class RoleSelectionSheet extends StatefulWidget {
  const RoleSelectionSheet({super.key});

  // Удобный вызов: показать модально (не закрывается свайпом — выбор обязателен).
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const RoleSelectionSheet(),
    );
  }

  @override
  State<RoleSelectionSheet> createState() => _RoleSelectionSheetState();
}

class _RoleSelectionSheetState extends State<RoleSelectionSheet> {
  final _repo = ProfileRepository();
  bool _saving = false;

  Future<void> _pick(String userType) async {
    setState(() => _saving = true);
    try {
      await _repo.selectRole(userType);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить выбор: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Как вы будете пользоваться Auto.RS?',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            _RoleCard(
              icon: Icons.search,
              title: 'Ищу машину',
              subtitle: 'Покупка и аренда авто',
              onTap: _saving ? null : () => _pick('customer'),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              icon: Icons.vpn_key,
              title: 'Сдаю машину',
              subtitle: 'Продажа и сдача в аренду',
              onTap: _saving ? null : () => _pick('vendor'),
            ),

            if (_saving) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

// Большая карточка-кнопка роли
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

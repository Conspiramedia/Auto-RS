// ============================================================
// AUTO.RS — Экран KYC-модерации (админ). Очередь профилей в статусе
// pending → просмотр документов (через signed URL приватного бакета)
// → одобрить (approve_user_verification) / отклонить (reject...).
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/models/profile_model.dart';
import '../../../data/repositories/verification_repository.dart';

class KycModerationScreen extends StatefulWidget {
  const KycModerationScreen({super.key});

  @override
  State<KycModerationScreen> createState() => _KycModerationScreenState();
}

class _KycModerationScreenState extends State<KycModerationScreen> {
  final _repo = VerificationRepository();

  late Future<List<ProfileModel>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchPendingQueue();
  }

  void _reload() => setState(() => _future = _repo.fetchPendingQueue());

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Показать документ по signed URL (приватный бакет)
  Future<void> _viewDoc(String? path, String title) async {
    if (path == null) {
      _snack('Документ не загружен');
      return;
    }
    try {
      final url = await _repo.createSignedUrl(path, expiresInSec: 300);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(title,
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    errorBuilder: (_, __, ___) =>
                        const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Не удалось загрузить изображение'),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _snack('Ошибка загрузки документа: $e');
    }
  }

  // Одобрить верификацию
  Future<void> _approve(ProfileModel p) async {
    setState(() => _busy = true);
    try {
      await _repo.approve(p.id);
      _snack('Пользователь верифицирован');
      _reload();
    } catch (e) {
      _snack(_humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Отклонить с причиной
  Future<void> _reject(ProfileModel p) async {
    final comment = await _askReason();
    if (comment == null) return;
    if (comment.trim().isEmpty) {
      _snack('Укажите причину отклонения');
      return;
    }
    setState(() => _busy = true);
    try {
      await _repo.reject(p.id, comment.trim());
      _snack('Верификация отклонена');
      _reload();
    } catch (e) {
      _snack(_humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askReason() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Причина отклонения'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Что не так с документами',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Отклонить'),
          ),
        ],
      ),
    );
  }

  String _humanError(Object e) {
    final s = e.toString();
    if (s.contains('прав') || s.contains('privilege')) {
      return 'Доступ только для администраторов';
    }
    return 'Ошибка: $s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Верификация KYC')),
      body: FutureBuilder<List<ProfileModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final profiles = snapshot.data ?? [];
          if (profiles.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Очередь верификации пуста')),
                ],
              ),
            );
          }
          return AbsorbPointer(
            absorbing: _busy,
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.builder(
                itemCount: profiles.length,
                itemBuilder: (context, i) {
                  final p = profiles[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.fullName ?? p.email,
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          Text(p.email,
                              style:
                                  Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 8),
                          // Просмотр документов
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _viewDoc(p.passportUrl, 'Паспорт'),
                                icon: const Icon(Icons.badge, size: 18),
                                label: const Text('Паспорт'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _viewDoc(
                                    p.driverLicenseUrl, 'Права'),
                                icon: const Icon(Icons.drive_eta, size: 18),
                                label: const Text('Права'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Решение
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () => _reject(p),
                                child: const Text('Отклонить'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: () => _approve(p),
                                child: const Text('Одобрить'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

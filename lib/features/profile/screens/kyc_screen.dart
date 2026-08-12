// ============================================================
// AUTO.RS — Экран верификации (KYC). Три состояния по verification_status:
//   unverified/rejected → форма загрузки документов;
//   pending             → ожидание проверки;
//   verified            → успех.
// Документы грузятся в приватный бакет user-documents, затем
// submit_verification переводит статус в pending.
// ============================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/enums/verification_status.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/verification_repository.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _profileRepo = ProfileRepository();
  final _verifyRepo = VerificationRepository();
  final _picker = ImagePicker();

  late Future<ProfileModel?> _future;

  // Пути загруженных документов в бакете
  String? _passportPath;
  String? _licensePath;

  bool _uploadingPassport = false;
  bool _uploadingLicense = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _profileRepo.fetchMyProfile();
  }

  void _reload() {
    setState(() => _future = _profileRepo.fetchMyProfile());
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Загрузка одного документа
  Future<void> _uploadDoc(String docName) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() {
      if (docName == 'passport') {
        _uploadingPassport = true;
      } else {
        _uploadingLicense = true;
      }
    });
    try {
      final bytes = await file.readAsBytes();
      final path = await _verifyRepo.uploadDocument(
        docName: docName,
        bytes: bytes,
      );
      setState(() {
        if (docName == 'passport') {
          _passportPath = path;
        } else {
          _licensePath = path;
        }
      });
    } catch (e) {
      _snack('Не удалось загрузить документ: $e');
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPassport = false;
          _uploadingLicense = false;
        });
      }
    }
  }

  // Отправка на проверку
  Future<void> _submit() async {
    if (_passportPath == null || _licensePath == null) {
      _snack('Загрузите оба документа');
      return;
    }
    setState(() => _submitting = true);
    try {
      await _verifyRepo.submitVerification(
        passportUrl: _passportPath!,
        driverLicenseUrl: _licensePath!,
      );
      _snack('Документы отправлены на проверку');
      _reload(); // статус станет pending → покажется блок ожидания
    } catch (e) {
      _snack('Ошибка отправки: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Верификация')),
      body: FutureBuilder<ProfileModel?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data;
          if (profile == null) {
            return const Center(child: Text('Профиль недоступен'));
          }
          return _buildByStatus(profile);
        },
      ),
    );
  }

  Widget _buildByStatus(ProfileModel profile) {
    switch (profile.verificationStatus) {
      case VerificationStatus.pending:
        return _centered(
          icon: Icons.hourglass_top,
          color: Colors.orange,
          title: 'Документы на проверке',
          text: 'Обычно занимает до 24 часов.',
        );
      case VerificationStatus.verified:
        return _centered(
          icon: Icons.verified,
          color: Colors.green,
          title: 'Аккаунт верифицирован',
          text: 'Вам доступна аренда автомобилей.',
        );
      case VerificationStatus.unverified:
      case VerificationStatus.rejected:
        return _buildUploadForm(profile);
    }
  }

  // Форма загрузки (для unverified и rejected)
  Widget _buildUploadForm(ProfileModel profile) {
    final isRejected =
        profile.verificationStatus == VerificationStatus.rejected;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Причина отклонения (только для rejected)
        if (isRejected && profile.verificationComment != null)
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Причина отклонения:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(profile.verificationComment!),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Для аренды авто подтвердите личность — загрузите паспорт и '
          'водительское удостоверение.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),

        _DocTile(
          label: 'Паспорт',
          uploaded: _passportPath != null,
          uploading: _uploadingPassport,
          onTap: () => _uploadDoc('passport'),
        ),
        const SizedBox(height: 12),
        _DocTile(
          label: 'Водительское удостоверение',
          uploaded: _licensePath != null,
          uploading: _uploadingLicense,
          onTap: () => _uploadDoc('license'),
        ),

        const SizedBox(height: 24),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Отправить на проверку'),
        ),
      ],
    );
  }

  Widget _centered({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// Плитка загрузки одного документа
class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.label,
    required this.uploaded,
    required this.uploading,
    required this.onTap,
  });

  final String label;
  final bool uploaded;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: uploading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(uploaded ? Icons.check_circle : Icons.upload_file,
                color: uploaded ? Colors.green : null),
        title: Text(label),
        subtitle: Text(uploaded ? 'Загружено' : 'Нажмите, чтобы загрузить'),
        onTap: uploading ? null : onTap,
      ),
    );
  }
}

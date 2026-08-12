// ============================================================
// AUTO.RS — Репозиторий KYC-верификации.
// Отправка документов пользователем + модерация админом (RPC миграции 0019).
// Файлы документов лежат в ПРИВАТНОМ бакете user-documents (доступ по signed URL).
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/profile_model.dart';

class VerificationRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  static const String _bucket = 'user-documents';

  // ----------------------------------------------------------
  // Подписанный URL для приватного документа (действует ограниченное время).
  // Нужен, чтобы показать паспорт/права владельцу или админу — прямой ссылки
  // у приватного бакета нет.
  // path — путь в бакете вида "<uid>/passport.jpg".
  // ----------------------------------------------------------
  Future<String> createSignedUrl(String path, {int expiresInSec = 3600}) async {
    return _client.storage.from(_bucket).createSignedUrl(path, expiresInSec);
  }

  // ----------------------------------------------------------
  // Отправка документов на проверку (RPC submit_verification).
  // Статус профиля → pending. URL получают заранее после загрузки в бакет.
  // ----------------------------------------------------------
  Future<ProfileModel> submitVerification({
    required String passportUrl,
    required String driverLicenseUrl,
  }) async {
    final row = await _client.rpc('submit_verification', params: {
      'p_passport_url': passportUrl,
      'p_driver_license_url': driverLicenseUrl,
    });
    return ProfileModel.fromMap(row as Map<String, dynamic>);
  }

  // ----------------------------------------------------------
  // Очередь верификации для админа: профили в статусе pending.
  // RLS profiles сейчас отдаёт пользователю только свой профиль, поэтому
  // для админ-очереди нужна отдельная политика/представление — см. примечание.
  // ----------------------------------------------------------
  Future<List<ProfileModel>> fetchPendingQueue() async {
    final rows = await _client
        .from('profiles')
        .select()
        .eq('verification_status', 'pending')
        .order('updated_at', ascending: true);

    return (rows as List)
        .map((e) => ProfileModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ----------------------------------------------------------
  // Админ: подтвердить верификацию (RPC approve_user_verification).
  // ----------------------------------------------------------
  Future<ProfileModel> approve(String userId) async {
    final row = await _client.rpc('approve_user_verification', params: {
      'p_user_id': userId,
    });
    return ProfileModel.fromMap(row as Map<String, dynamic>);
  }

  // ----------------------------------------------------------
  // Админ: отклонить верификацию с причиной (RPC reject_user_verification).
  // ----------------------------------------------------------
  Future<ProfileModel> reject(String userId, String comment) async {
    final row = await _client.rpc('reject_user_verification', params: {
      'p_user_id': userId,
      'p_comment': comment,
    });
    return ProfileModel.fromMap(row as Map<String, dynamic>);
  }
}

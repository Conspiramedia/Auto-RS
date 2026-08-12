// ============================================================
// AUTO.RS — Репозиторий профиля текущего пользователя.
// Чтение своего профиля (RLS отдаёт только свою строку).
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // Профиль текущего пользователя (по auth.uid()).
  Future<ProfileModel?> fetchMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;
    return ProfileModel.fromMap(row);
  }
}

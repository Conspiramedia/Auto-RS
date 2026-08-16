// ============================================================
// AUTO.RS — Репозиторий профиля текущего пользователя.
// Чтение своего профиля (RLS отдаёт только свою строку).
// ============================================================

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/dealer_profile_model.dart';
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

  // Выбор роли при онбординге: записывает user_type и отмечает,
  // что онбординг пройден (role_selected = true). userType: 'customer'|'vendor'.
  // RLS profiles_update_own разрешает менять только свою строку.
  Future<void> selectRole(String userType) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Требуется авторизация');

    await _client.from('profiles').update({
      'user_type': userType,
      'role_selected': true,
    }).eq('id', userId);
  }

  // Обновление имени и/или аватара. Меняем только переданные поля
  // (null-аргумент = не трогаем). RLS разрешает менять только свою строку.
  Future<void> updateProfile({String? fullName, String? avatarUrl}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Требуется авторизация');

    final patch = <String, dynamic>{};
    if (fullName != null) patch['full_name'] = fullName.trim();
    if (avatarUrl != null) patch['avatar_url'] = avatarUrl;
    if (patch.isEmpty) return;

    await _client.from('profiles').update(patch).eq('id', userId);
  }

  // Загрузка аватара в bucket 'avatars' по пути "<uid>/avatar.jpg" (upsert:
  // заменяет прежний). Возвращает публичный URL с cache-buster, чтобы UI
  // сразу показал новую картинку, а не старую из кэша.
  Future<String> uploadAvatar(List<int> bytes) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Требуется авторизация');

    final path = '$userId/avatar.jpg';
    await _client.storage.from('avatars').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    final base = _client.storage.from('avatars').getPublicUrl(path);
    // Обходим кэш: тот же путь после перезаписи вернул бы старое фото.
    return '$base?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  // ---------- ПРОДАВЕЦ: частник / автосалон ----------

  // Публичная карточка продавца для страницы дилера. Доступна и гостю:
  // прямой SELECT из profiles закрыт RLS, поэтому читаем через RPC, которая
  // отдаёт только разрешённые к показу поля.
  Future<DealerProfileModel?> fetchDealerProfile(String userId) async {
    final rows = await _client.rpc('get_dealer_profile', params: {
      'p_user_id': userId,
    });

    // RPC возвращает setof — при несуществующем id список пуст.
    final list = rows as List;
    if (list.isEmpty) return null;
    return DealerProfileModel.fromMap(list.first as Map<String, dynamic>);
  }

  // Объявления продавца для страницы дилера.
  // status: 'active' — витрина, 'sold' — блок «недавно проданные».
  // Другие статусы сервер не отдаёт: модерация и архив — внутренняя кухня
  // продавца, посторонним они не видны.
  Future<List<SellerListingModel>> fetchSellerListings(
    String userId, {
    String status = 'active',
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _client.rpc('get_seller_listings', params: {
      'p_user_id': userId,
      'p_status': status,
      'p_limit': limit,
      'p_offset': offset,
    });

    return (rows as List)
        .map((e) => SellerListingModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // Переключение частник/дилер и поля витрины. Сервер валидирует: дилер без
  // названия салона не сохранится, а при возврате в 'private' поля витрины
  // очищаются, чтобы не оставался мусор от прошлой роли.
  Future<ProfileModel> updateSellerProfile({
    required String sellerKind,
    String? companyName,
    String? logoUrl,
  }) async {
    final row = await _client.rpc('update_seller_profile', params: {
      'p_seller_kind': sellerKind,
      'p_company_name': companyName,
      'p_logo_url': logoUrl,
    });
    return ProfileModel.fromMap(row as Map<String, dynamic>);
  }

  // Загрузка логотипа автосалона в тот же bucket 'avatars', но отдельным
  // путём — логотип и личный аватар должны существовать независимо.
  Future<String> uploadDealerLogo(List<int> bytes) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Требуется авторизация');

    final path = '$userId/logo.jpg';
    await _client.storage.from('avatars').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    final base = _client.storage.from('avatars').getPublicUrl(path);
    return '$base?v=${DateTime.now().millisecondsSinceEpoch}';
  }
}

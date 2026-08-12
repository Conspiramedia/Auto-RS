// ============================================================
// AUTO.RS — Модель ProfileModel (зеркало таблицы public.profiles).
// ============================================================

import '../enums/user_role.dart';
import '../enums/verification_status.dart';

class ProfileModel {
  final String id;         // = auth.users.id
  final String email;
  final String? fullName;  // ФИО
  final String? phone;
  final UserRole role;
  final bool isAdmin;         // признак администратора (доступ к модерации)
  final String userType;      // 'customer' | 'vendor'
  final bool roleSelected;    // прошёл ли онбординг выбора роли
  final String? avatarUrl;

  // KYC-верификация
  final VerificationStatus verificationStatus;
  final String? passportUrl;
  final String? driverLicenseUrl;
  final String? verificationComment;   // причина отклонения

  final DateTime createdAt;
  final DateTime updatedAt;

  const ProfileModel({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    required this.role,
    this.isAdmin = false,
    this.userType = 'customer',
    this.roleSelected = false,
    this.avatarUrl,
    this.verificationStatus = VerificationStatus.unverified,
    this.passportUrl,
    this.driverLicenseUrl,
    this.verificationComment,
    required this.createdAt,
    required this.updatedAt,
  });

  // true, если пользователь прошёл верификацию (для допуска к аренде и т.п.)
  bool get isVerified => verificationStatus == VerificationStatus.verified;

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: map['id'] as String,
      email: map['email'] as String,
      fullName: map['full_name'] as String?,
      phone: map['phone'] as String?,
      role: UserRole.fromValue(map['role'] as String?),
      isAdmin: map['is_admin'] as bool? ?? false,
      userType: map['user_type'] as String? ?? 'customer',
      roleSelected: map['role_selected'] as bool? ?? false,
      avatarUrl: map['avatar_url'] as String?,
      verificationStatus:
          VerificationStatus.fromValue(map['verification_status'] as String?),
      passportUrl: map['passport_url'] as String?,
      driverLicenseUrl: map['driver_license_url'] as String?,
      verificationComment: map['verification_comment'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Для UPDATE профиля клиентом (email/role/id не меняем отсюда)
  Map<String, dynamic> toUpdateMap() {
    return {
      'full_name': fullName,
      'phone': phone,
      'avatar_url': avatarUrl,
    };
  }
}

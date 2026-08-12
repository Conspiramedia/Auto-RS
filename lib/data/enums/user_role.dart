// ============================================================
// AUTO.RS — Enum роли пользователя (зеркало user_role в БД).
// ============================================================

enum UserRole {
  client('client'),
  seller('seller'),
  admin('admin');

  final String value;
  const UserRole(this.value);

  static UserRole fromValue(String? value) {
    return UserRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserRole.client,
    );
  }
}

// ============================================================
// AUTO.RS — Enum статуса KYC-верификации (зеркало verification_status_type).
// ============================================================

enum VerificationStatus {
  unverified('unverified'), // документы не подавались
  pending('pending'),       // на проверке у админа
  verified('verified'),     // подтверждён
  rejected('rejected');     // отклонён (см. verification_comment)

  final String value;
  const VerificationStatus(this.value);

  static VerificationStatus fromValue(String? value) {
    return VerificationStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => VerificationStatus.unverified,
    );
  }
}

// ============================================================
// AUTO.RS — Enum коробки передач (зеркало transmission_type в БД).
// ============================================================

enum TransmissionType {
  manual('manual'),
  automatic('automatic'),
  robot('robot'),
  variator('variator');

  final String value;
  const TransmissionType(this.value);

  static TransmissionType? fromValue(String? value) {
    if (value == null) return null;
    for (final e in TransmissionType.values) {
      if (e.value == value) return e;
    }
    return null;
  }
}

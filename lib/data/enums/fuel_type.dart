// ============================================================
// AUTO.RS — Enum типа топлива (зеркало fuel_type в БД).
// ============================================================

enum FuelType {
  petrol('petrol'),
  diesel('diesel'),
  hybrid('hybrid'),
  electric('electric'),
  gas('gas');

  final String value;
  const FuelType(this.value);

  static FuelType? fromValue(String? value) {
    if (value == null) return null;
    for (final e in FuelType.values) {
      if (e.value == value) return e;
    }
    return null;
  }
}

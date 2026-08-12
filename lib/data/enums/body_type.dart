// ============================================================
// AUTO.RS — Enum типа кузова (зеркало body_type в БД).
// ============================================================

enum BodyType {
  sedan('sedan'),
  hatchback('hatchback'),
  suv('suv'),
  crossover('crossover'),
  coupe('coupe'),
  wagon('wagon'),
  minivan('minivan'),
  pickup('pickup'),
  convertible('convertible'),
  van('van');

  final String value;
  const BodyType(this.value);

  static BodyType? fromValue(String? value) {
    if (value == null) return null;
    for (final e in BodyType.values) {
      if (e.value == value) return e;
    }
    return null;
  }
}

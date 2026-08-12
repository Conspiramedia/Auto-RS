// ============================================================
// AUTO.RS — Enum валюты (зеркало currency_code в БД).
// В базе храним EUR; RSD используется для показа на клиенте.
// ============================================================

enum CurrencyCode {
  eur('EUR'),
  rsd('RSD');

  final String value;
  const CurrencyCode(this.value);

  static CurrencyCode fromValue(String? value) {
    return CurrencyCode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CurrencyCode.eur,
    );
  }
}

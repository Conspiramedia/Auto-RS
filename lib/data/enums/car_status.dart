// ============================================================
// AUTO.RS — Enum статуса объявления (зеркало car_status в БД).
// Значения строк ДОЛЖНЫ совпадать с ENUM car_status в PostgreSQL,
// иначе сериализация в Supabase сломается.
// ============================================================

enum CarStatus {
  draft('draft'),           // черновик (ещё не отправлен на модерацию)
  moderation('moderation'), // ждёт одобрения админом (по умолчанию после создания)
  active('active'),         // одобрено, видно в поиске
  archived('archived'),     // скрыто владельцем
  rejected('rejected'),     // отклонено модератором
  sold('sold');             // продано

  // Строковое значение ровно как в БД
  final String value;
  const CarStatus(this.value);

  // Парсинг из строки, пришедшей из Supabase.
  // Неизвестное значение → moderation (безопасный дефолт).
  static CarStatus fromValue(String? value) {
    return CarStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CarStatus.moderation,
    );
  }
}

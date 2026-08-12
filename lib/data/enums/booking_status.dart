// ============================================================
// AUTO.RS — Enum статуса брони (зеркало booking_status в БД).
// Значения строк ДОЛЖНЫ совпадать с ENUM booking_status в PostgreSQL.
// ============================================================

enum BookingStatus {
  pending('pending'),     // заявка подана, даты НЕ блокируются
  confirmed('confirmed'), // подтверждена владельцем, даты блокируются
  paid('paid'),           // оплачена клиентом (payment проведён)
  rejected('rejected'),   // отклонена владельцем
  cancelled('cancelled'), // отменена клиентом
  completed('completed'); // аренда завершена

  final String value;
  const BookingStatus(this.value);

  static BookingStatus fromValue(String? value) {
    return BookingStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BookingStatus.pending,
    );
  }
}

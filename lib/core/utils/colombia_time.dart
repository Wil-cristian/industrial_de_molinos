/// Utilidad centralizada para zona horaria de Colombia (UTC-5).
///
/// Colombia NO tiene horario de verano, siempre es UTC-5.
/// Usar esta clase en lugar de DateTime.now() y .toIso8601String() directamente.
class ColombiaTime {
  ColombiaTime._();

  /// Offset de Colombia: UTC-5
  static const Duration _offset = Duration(hours: -5);

  /// Hora actual en Colombia, independiente de la zona del dispositivo.
  static DateTime now() {
    final utcNow = DateTime.now().toUtc();
    return utcNow.add(_offset);
  }

  /// Fecha de hoy en Colombia como string 'YYYY-MM-DD'.
  static String todayString() {
    final n = now();
    return _dateOnly(n);
  }

  /// Convierte un DateTime a string de solo fecha 'YYYY-MM-DD' en hora Colombia.
  /// Si [date] ya representa hora Colombia (viene de [now()]), lo usa directo.
  /// Si [date] es UTC, lo convierte primero.
  static String dateString(DateTime date) {
    final colombiaDate = toColombia(date);
    return _dateOnly(colombiaDate);
  }

  /// Convierte cualquier DateTime a hora Colombia.
  static DateTime toColombia(DateTime date) {
    if (date.isUtc) {
      return date.add(_offset);
    }
    // Si es local, primero a UTC, luego a Colombia
    return date.toUtc().add(_offset);
  }

  /// Convierte una hora Colombia a UTC (para guardar en BD).
  static DateTime toUtc(DateTime colombiaDate) {
    // Colombia es UTC-5, entonces sumar 5h da UTC
    return DateTime.utc(
      colombiaDate.year,
      colombiaDate.month,
      colombiaDate.day,
      colombiaDate.hour + 5,
      colombiaDate.minute,
      colombiaDate.second,
      colombiaDate.millisecond,
    );
  }

  /// ISO8601 con offset explícito de Colombia (-05:00) para timestamps.
  /// Ejemplo: '2026-04-10T14:30:00.000-05:00'
  static String nowIso8601() {
    return toIso8601(now());
  }

  /// Convierte un DateTime a ISO8601 con offset de Colombia (-05:00).
  static String toIso8601(DateTime date) {
    final d = toColombia(date);
    final iso =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}T'
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}:'
        '${d.second.toString().padLeft(2, '0')}.'
        '${d.millisecond.toString().padLeft(3, '0')}-05:00';
    return iso;
  }

  /// Inicio del día en Colombia como ISO8601 con offset.
  /// Útil para queries de rango: .gte('date', ColombiaTime.startOfDayIso(date))
  static String startOfDayIso(DateTime date) {
    final d = toColombia(date);
    final start = DateTime(d.year, d.month, d.day);
    return toIso8601(start);
  }

  /// Fin del día en Colombia (inicio del siguiente día) como ISO8601 con offset.
  /// Útil para queries de rango: .lt('date', ColombiaTime.endOfDayIso(date))
  static String endOfDayIso(DateTime date) {
    final d = toColombia(date);
    final end = DateTime(d.year, d.month, d.day + 1);
    return toIso8601(end);
  }

  /// Inicio de mes en Colombia como ISO8601 con offset.
  static String startOfMonthIso(int year, int month) {
    final start = DateTime(year, month, 1);
    return toIso8601(start);
  }

  /// Fin de mes en Colombia (inicio del siguiente mes) como ISO8601 con offset.
  static String endOfMonthIso(int year, int month) {
    final end = DateTime(year, month + 1, 1);
    return toIso8601(end);
  }

  /// Formato 'YYYY-MM-DD'
  static String _dateOnly(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

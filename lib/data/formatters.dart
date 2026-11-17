/// Formatos de números y fechas en español que usan varias pantallas.
/// Son funciones sueltas (en Java serían métodos estáticos de una clase de
/// utilidades).
library;

/// Abreviatura de cada mes, de enero a diciembre.
const monthAbbreviations = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Número entero con punto de miles: 10000 → "10.000".
String formatThousands(num value) {
  final digits = value.round().toString();
  return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
}

/// Kilos con un decimal y coma: 78.44 → "78,4".
String formatKg(double kg) => kg.toStringAsFixed(1).replaceAll('.', ',');

/// Fecha corta: "10 nov".
String shortDate(DateTime date) =>
    '${date.day} ${monthAbbreviations[date.month - 1]}';

/// "Hoy", "Ayer" o la fecha corta ("10 nov") de [day] respecto a [today].
String relativeDayLabel(DateTime day, DateTime today) {
  final date = DateTime(day.year, day.month, day.day);
  final todayDate = DateTime(today.year, today.month, today.day);
  if (date == todayDate) return 'Hoy';
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  if (date == yesterday) return 'Ayer';
  return shortDate(date);
}

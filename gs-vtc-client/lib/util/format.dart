import 'package:intl/intl.dart';

// Formats français, heure de Paris (l'appareil peut être réglé ailleurs : on affiche l'heure locale de l'appareil,
// qui est celle du chauffeur sur place).
final _money = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2);

String money(Object? value) {
  final amount = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  // Le format fr_FR met des espaces insécables (U+00A0, U+202F) : on garde de vrais espaces, comme au clavier.
  return _money.format(amount).replaceAll(RegExp('[\u00a0\u202f]'), ' ');
}

String dateTime(DateTime value) => DateFormat("EEE d MMM 'à' HH:mm", 'fr_FR').format(value.toLocal());

String dayLabel(DateTime value) {
  final local = value.toLocal();
  final today = DateTime.now();
  final date = DateTime(local.year, local.month, local.day);
  final difference = date.difference(DateTime(today.year, today.month, today.day)).inDays;
  if (difference == 0) return "Aujourd'hui";
  if (difference == 1) return 'Demain';
  if (difference == -1) return 'Hier';
  return _capitalize(DateFormat('EEEE d MMMM', 'fr_FR').format(local));
}

String time(DateTime value) => DateFormat('HH:mm', 'fr_FR').format(value.toLocal());

String monthLabel(String isoMonth) => _capitalize(DateFormat('MMMM yyyy', 'fr_FR').format(DateTime.parse(isoMonth)));

// "9 All. de la Feuillée, 74160 Saint-Julien, France" -> "9 All. de la Feuillée"
String shortAddress(String address) => address.split(',').first.trim();

String _capitalize(String value) => value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

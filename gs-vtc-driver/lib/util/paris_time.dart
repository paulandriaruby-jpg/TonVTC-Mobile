import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// Heure du service : Paris (Europe/Paris), quel que soit le fuseau du téléphone. Un client qui réserve depuis
// l'étranger choisit l'heure de prise en charge sur place, et toutes les heures s'affichent à l'heure de Paris.
// Les instants échangés avec l'API restent en heure universelle (UTC).
tz.Location? _paris;

tz.Location get paris => _paris ??= () {
  tzdata.initializeTimeZones();
  return tz.getLocation('Europe/Paris');
}();

// Un instant, exprimé à l'heure de Paris (ses year, month, day, hour, minute sont ceux de Paris).
tz.TZDateTime inParis(DateTime value) => tz.TZDateTime.from(value, paris);

tz.TZDateTime parisNow() => tz.TZDateTime.now(paris);

// Une date et une heure "sur place", à Paris.
tz.TZDateTime parisTime(
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
]) => tz.TZDateTime(paris, year, month, day, hour, minute);

// Le jour (calendrier de Paris) d'un instant, pour compter les jours sans effet des changements d'heure.
DateTime parisDay(DateTime value) {
  final local = inParis(value);
  return DateTime.utc(local.year, local.month, local.day);
}

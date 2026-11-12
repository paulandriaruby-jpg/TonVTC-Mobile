import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_client/booking/rules.dart';
import 'package:gs_vtc_client/util/format.dart' as fmt;
import 'package:gs_vtc_client/util/paris_time.dart';
import 'package:intl/date_symbol_data_local.dart';

// Les heures s'affichent et se choisissent à l'heure de Paris, quel que soit le fuseau du téléphone
// (ces tests passent aussi avec TZ=America/New_York).
void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  test("affiche l'heure de Paris d'un instant (hiver +1 h, été +2 h)", () {
    expect(fmt.time(DateTime.utc(2026, 1, 15, 12)), '13:00');
    expect(fmt.time(DateTime.utc(2026, 7, 15, 12)), '14:00');
    expect(fmt.dateTime(DateTime.utc(2026, 11, 30, 23, 30)), startsWith('mar. 1 déc.'));
  });

  test("une heure choisie est une heure de Paris, envoyée en UTC à l'API", () {
    final chosen = roundToQuarter(parisTime(2026, 12, 1, 9, 7));
    expect([inParis(chosen).hour, inParis(chosen).minute], [9, 15]);
    expect(chosen.toUtc().toIso8601String(), '2026-12-01T08:15:00.000Z');
  });

  test('le premier créneau est 2 h plus tard, au quart d\'heure suivant, à l\'heure de Paris', () {
    final first = inParis(minimumDeparture(DateTime.utc(2026, 12, 1, 7, 50)));
    expect([first.hour, first.minute], [11, 0]); // 08:50 à Paris + 2 h = 10:50, arrondi à 11:00
  });
}

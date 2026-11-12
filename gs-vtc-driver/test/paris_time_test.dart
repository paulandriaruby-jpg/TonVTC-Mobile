import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_driver/util/format.dart' as fmt;
import 'package:gs_vtc_driver/util/paris_time.dart';
import 'package:gs_vtc_driver/widgets/ride_day.dart';
import 'package:intl/date_symbol_data_local.dart';

// Les heures et les jours sont ceux de Paris, quel que soit le fuseau du téléphone
// (ces tests passent aussi avec TZ=America/New_York).
void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  test("affiche l'heure de Paris d'un instant (hiver +1 h, été +2 h)", () {
    expect(fmt.time(DateTime.utc(2026, 1, 15, 12)), '13:00');
    expect(fmt.time(DateTime.utc(2026, 7, 15, 12)), '14:00');
  });

  test('aujourd\'hui et demain se comptent à minuit, heure de Paris', () {
    final now = DateTime.utc(2026, 11, 30, 23, 30); // 00:30 le 1er décembre à Paris
    expect(rideDay(parisTime(2026, 12, 1, 10), now), RideDay.today);
    expect(rideDay(parisTime(2026, 12, 2, 8), now), RideDay.tomorrow);
    expect(rideDay(parisTime(2026, 12, 3, 8), now), RideDay.later);
  });
}

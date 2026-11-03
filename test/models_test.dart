import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_driver/models/models.dart';
import 'package:gs_vtc_driver/util/format.dart';
import 'package:intl/date_symbol_data_local.dart';

Map<String, dynamic> ride({String status = 'accepted', String? departed, String? arrived}) => {
      'id': 1, 'reference': 'GSV-abcdef123456', 'status': status, 'payment_status': 'paid', 'trip_type': 'one_way',
      'pickup_address': '9 All. de la Feuillée, 74160 Saint-Julien-en-Genevois, France', 'destination_address': 'Annemasse, France',
      'departure_at': '2026-11-05T08:30:00Z', 'quoted_price': '46.0', 'driver_share': null, 'departed_at': departed, 'arrived_at': arrived,
      'permissions': {'depart': true, 'arrive': true},
      'transport_number': 'EZY1234', 'sign_name': 'M. Durand', 'arrival_delay_minutes': arrived == null ? null : 12, 'late': arrived != null,
    };

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  test('étape de la course côté chauffeur', () {
    expect(Ride.fromJson(ride(status: 'dispatched')).step, RideStep.toAccept);
    expect(Ride.fromJson(ride()).step, RideStep.accepted);
    expect(Ride.fromJson(ride(departed: '2026-11-05T08:00:00Z')).step, RideStep.onTheWay);
    expect(Ride.fromJson(ride(departed: '2026-11-05T08:00:00Z', arrived: '2026-11-05T08:25:00Z')).step, RideStep.arrived);
    expect(Ride.fromJson(ride(status: 'in_progress')).step, RideStep.inProgress);
    expect(Ride.fromJson(ride(status: 'completed')).step, RideStep.completed);
    final late = Ride.fromJson(ride(departed: '2026-11-05T08:00:00Z', arrived: '2026-11-05T08:42:00Z'));
    expect(late.late, isTrue);
    expect(late.arrivalDelayMinutes, 12);
    expect(late.signName, 'M. Durand');
    final accepted = Ride.fromJson(ride());
    expect(accepted.can('depart'), isTrue);
    expect(accepted.can('finish'), isFalse);
  });

  test('à recevoir = dû non relevé + relevés en préparation', () {
    final earnings = Earnings.fromJson({
      'commission_rate': '20.0', 'due': '40.0', 'awaiting_client': '12.5',
      'months': [{'month': '2026-11-01', 'bookings_count': 1, 'earned': '40.0', 'paid': '0.0', 'to_receive': '40.0'}],
      'payouts': [
        {'id': 1, 'label': 'Octobre 2026', 'amount': '275.36', 'bookings_count': 3, 'status': 'pending'},
        {'id': 2, 'label': 'Septembre 2026', 'amount': '147.28', 'bookings_count': 2, 'status': 'paid', 'paid_at': '2026-10-05T10:00:00Z'},
      ],
    });
    expect(earnings.toReceive, closeTo(315.36, 0.001));
    expect(earnings.payouts.last.paid, isTrue);
  });

  test('formats français', () {
    expect(money('1234.5').replaceAll(' ', ' ').replaceAll(' ', ' '), '1 234,50 €');
    expect(shortAddress('9 All. de la Feuillée, 74160 Saint-Julien, France'), '9 All. de la Feuillée');
    expect(monthLabel('2026-10-01'), 'Octobre 2026');
  });
}

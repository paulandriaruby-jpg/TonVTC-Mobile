import '../models/models.dart';
import 'api_client.dart';

// Routes de l'API utilisées par l'app client.
class ClientApi {
  ClientApi(this.client);

  final ApiClient client;

  Future<List<PlaceSuggestion>> suggestions(String input, String sessionToken) async {
    final data = await client.get('/api/v1/places', query: {'input': input, 'session_token': sessionToken}) as Map<String, dynamic>;
    return (data['data'] as List).map((s) => PlaceSuggestion.fromJson(s as Map<String, dynamic>)).toList();
  }

  Future<Place> place(String placeId, String sessionToken) async =>
      Place.fromJson(await client.get('/api/v1/places/$placeId', query: {'session_token': sessionToken}) as Map<String, dynamic>);

  Future<Quote> quote(Map<String, dynamic> trip) async => Quote.fromJson(await client.post('/api/v1/quotes', trip) as Map<String, dynamic>);

  Future<({String code, String name, double discount})> checkPromo(String code, double amount, String email) async {
    final data = await client.post('/api/v1/promo_code_checks', {'code': code, 'amount': amount.toStringAsFixed(2), 'email': email}) as Map<String, dynamic>;
    return (code: data['code'] as String, name: data['name'] as String, discount: double.parse('${data['discount']}'));
  }

  Future<double> creditBalance() async => double.tryParse('${(await client.get('/api/v1/credits') as Map<String, dynamic>)['balance']}') ?? 0;

  Future<Ride> createBooking(Map<String, dynamic> body) async => Ride.fromJson(await client.post('/api/v1/bookings', body) as Map<String, dynamic>);

  Future<Profile> profile() async => Profile.fromJson(await client.get('/api/v1/profile') as Map<String, dynamic>);

  Future<Profile> updateProfile({required String firstName, required String lastName, required String phone}) async =>
      Profile.fromJson(await client.patch('/api/v1/profile', {'first_name': firstName, 'last_name': lastName, 'phone': phone}) as Map<String, dynamic>);

  // period : « upcoming » (à venir) ou « past » (terminées / annulées).
  Future<List<Ride>> rides(String period) async {
    final data = await client.get('/api/v1/bookings', query: {'period': period, 'sort': 'departure_at', 'direction': period == 'upcoming' ? 'asc' : 'desc', 'per_page': '50'})
        as Map<String, dynamic>;
    return (data['data'] as List).map((r) => Ride.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Ride> ride(int id) async => Ride.fromJson(await client.get('/api/v1/bookings/$id') as Map<String, dynamic>);

  Future<({double fee, DateTime? freeUntil})> cancellationPreview(int id) async {
    final data = await client.get('/api/v1/bookings/$id/cancellation') as Map<String, dynamic>;
    return (fee: double.tryParse('${data['fee']}') ?? 0, freeUntil: DateTime.tryParse('${data['free_until']}'));
  }

  Future<void> cancel(int id) => client.post('/api/v1/bookings/$id/cancel');

  // TEMPORAIRE avant Systempay (développement uniquement ; refusé en production).
  Future<void> simulatePayment(String reference) => client.post('/api/v1/payment_simulations', {'reference': reference});
}

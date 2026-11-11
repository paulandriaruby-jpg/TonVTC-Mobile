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

  // period : "upcoming" (à venir) ou "past" (terminées / annulées).
  // Suppression du compte : ce qui l'empêche (course à venir, paiement en attente) et l'avoir qui serait perdu.
  Future<({bool allowed, String? reason, double creditBalance})> deletionCheck() async {
    final data = await client.get('/api/v1/profile/deletion') as Map<String, dynamic>;
    return (allowed: data['allowed'] == true, reason: data['reason'] as String?, creditBalance: double.tryParse('${data['credit_balance']}') ?? 0);
  }

  Future<void> deleteAccount() => client.post('/api/v1/profile/deletion');

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

  // Note du chauffeur d'une course terminée (une seule fois).
  Future<RideRating> rate(int id, {required int stars, String? comment}) async =>
      RideRating.fromJson(await client.post('/api/v1/bookings/$id/rating', {'stars': stars, if (comment != null && comment.isNotEmpty) 'comment': comment}) as Map<String, dynamic>);

  // Message à l'équipe, éventuellement à propos d'une course.
  Future<void> sendFeedback({required String category, required String body, int? bookingId}) =>
      client.post('/api/v1/feedbacks', {'category': category, 'body': body, 'booking_id': ?bookingId});

  // Paiement Stripe dans l'app : de quoi ouvrir la fenêtre de paiement native (PaymentIntent de la course).
  Future<PaymentSheetData> paymentSheet(String reference) async =>
      PaymentSheetData.fromJson(await client.post('/api/v1/payments', {'reference': reference, 'mode': 'sheet'}) as Map<String, dynamic>);

  // Après la fenêtre de paiement : état du paiement relu chez Stripe ("paid" quand c'est réglé).
  Future<String> confirmPayment(String reference) async =>
      ((await client.post('/api/v1/payments/confirm', {'reference': reference})) as Map<String, dynamic>)['payment_status'] as String;

  // Tests uniquement (développement ; refusé en production) : marque la course payée sans Stripe.
  Future<void> simulatePayment(String reference) => client.post('/api/v1/payment_simulations', {'reference': reference});
}

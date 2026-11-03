import '../models/models.dart';
import 'api_client.dart';

// Routes de l'API utilisées par l'app chauffeur.
class DriverApi {
  DriverApi(this.client);

  final ApiClient client;

  Future<List<Proposal>> proposals() async {
    final data = await client.get('/api/v1/proposals') as Map<String, dynamic>;
    return (data['data'] as List).map((p) => Proposal.fromJson(p as Map<String, dynamic>)).toList();
  }

  Future<Ride> acceptProposal(int proposalId) async => Ride.fromJson(await client.post('/api/v1/proposals/$proposalId/accept') as Map<String, dynamic>);

  Future<void> declineProposal(int proposalId) => client.post('/api/v1/proposals/$proposalId/decline');

  // period : « upcoming » (à faire) ou « past » (terminées / annulées).
  Future<List<Ride>> rides(String period) async {
    final data = await client.get('/api/v1/bookings', query: {
      'period': period,
      'sort': 'departure_at',
      'direction': period == 'upcoming' ? 'asc' : 'desc',
      'per_page': '50',
    }) as Map<String, dynamic>;
    return (data['data'] as List).map((r) => Ride.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Ride> ride(int id) async => Ride.fromJson(await client.get('/api/v1/bookings/$id') as Map<String, dynamic>);

  // Étapes : accepter (course attribuée), en route, arrivé, démarrer, terminer, refuser, se désister.
  Future<Ride> rideAction(int id, String action) async {
    final Object? data = switch (action) {
      'accept' => await client.patch('/api/v1/bookings/$id', {'status': 'accepted'}),
      'start' => await client.patch('/api/v1/bookings/$id', {'status': 'in_progress'}),
      'finish' => await client.patch('/api/v1/bookings/$id', {'status': 'completed'}),
      'depart' || 'arrive' || 'decline' || 'withdraw' => await client.post('/api/v1/bookings/$id/$action'),
      _ => throw ArgumentError('Action inconnue : $action'),
    };
    return data is Map<String, dynamic> ? Ride.fromJson(data) : ride(id);
  }

  // Remarque : simple information pour l'équipe (catégorie « remark », texte obligatoire).
  Future<void> remark(int id, String body) => report(id, category: 'remark', body: body);

  Future<void> report(int id, {required String category, String? body}) =>
      client.post('/api/v1/bookings/$id/report', {'category': category, 'body': body ?? ''});

  Future<Earnings> earnings() async => Earnings.fromJson(await client.get('/api/v1/earnings') as Map<String, dynamic>);

  Future<DriverProfile> profile() async => DriverProfile.fromJson(await client.get('/api/v1/profile') as Map<String, dynamic>);

  Future<DriverProfile> setAvailable(bool available) async =>
      DriverProfile.fromJson(await client.patch('/api/v1/profile', {'available': available}) as Map<String, dynamic>);
}

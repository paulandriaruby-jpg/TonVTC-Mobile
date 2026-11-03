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

  // Informations du dossier de recrutement (refusées par le serveur une fois le dossier relu par l'équipe).
  Future<DriverProfile> saveDetails(Map<String, dynamic> details) async =>
      DriverProfile.fromJson(await client.patch('/api/v1/profile', details) as Map<String, dynamic>);

  // Pièce justificative du chauffeur (photo ou PDF) ; le serveur vérifie le type réel du fichier (8 Mo maximum).
  // `carId` : pièce d'un véhicule (carte grise, assurance…) au lieu d'une pièce personnelle.
  Future<void> uploadDocument({required String kind, required List<int> bytes, required String filename, int? carId}) =>
      client.upload('/api/v1/profile/documents', fields: {'kind': kind, if (carId != null) 'car_id': '$carId'}, fileField: 'file', bytes: bytes, filename: filename);

  Future<List<VehicleCategory>> vehicleCategories() async =>
      (await client.get('/api/v1/vehicle_types') as List).map((v) => VehicleCategory.fromJson(v as Map<String, dynamic>)).toList();

  // Crée (`id` absent) ou modifie un véhicule ; renvoie le véhicule enregistré.
  Future<DriverCar> saveCar(Map<String, dynamic> car, {int? id}) async => DriverCar.fromJson((id == null
      ? await client.post('/api/v1/profile/cars', car)
      : await client.patch('/api/v1/profile/cars/$id', car)) as Map<String, dynamic>);

  Future<void> deleteCar(int id) => client.delete('/api/v1/profile/cars/$id');

  Future<void> deleteDocument(int id) => client.delete('/api/v1/profile/documents/$id');

  Future<DriverProfile> setAvailable(bool available) async =>
      DriverProfile.fromJson(await client.patch('/api/v1/profile', {'available': available}) as Map<String, dynamic>);
}

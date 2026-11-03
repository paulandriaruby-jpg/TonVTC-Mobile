import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_driver/api/api_client.dart';
import 'package:gs_vtc_driver/api/driver_api.dart';
import 'package:gs_vtc_driver/auth/session_store.dart';
import 'package:gs_vtc_driver/models/models.dart';
import 'package:gs_vtc_driver/recruitment/document_picker.dart';
import 'package:gs_vtc_driver/recruitment/recruitment.dart';
import 'package:gs_vtc_driver/screens/recruitment_car_screen.dart';
import 'package:gs_vtc_driver/screens/recruitment_cars_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

class FakePicker implements DocumentPicker {
  @override
  Future<PickedDocument?> pick(PickSource source) async => const PickedDocument(bytes: [1, 2, 3], filename: 'carte-grise.jpg');
}

http.Response json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> carJson({int id = 7, bool validated = false, bool rental = false, List<String> missing = const ['car_registration', 'car_insurance', 'car_picture'], List<Map<String, dynamic>> documents = const []}) => {
      'id': id,
      'vehicle_type_id': 1,
      'vehicle_type_name': 'Berline',
      'brand': 'PEUGEOT',
      'model': '508',
      'color': 'Noir',
      'plate_number': 'AB-123-CD',
      'motor': 'hybrid',
      'seats': 4,
      'wifi': false,
      'rental': rental,
      'enabled': true,
      'validation_status': validated ? 'validated' : 'incomplete',
      'validation_label': validated ? 'Validé' : 'Documents à fournir',
      'locked': validated,
      'documents_missing': missing,
      'documents': documents,
    };

Map<String, dynamic> profileJson({List<Map<String, dynamic>> cars = const []}) => {
      'user': {'first_name': 'Alice', 'last_name': 'Martin', 'email': 'alice@example.com'},
      'driver': {'validation_status': 'data_collected', 'locked': false, 'legal_status': 'self_employed', 'details_missing': <String>[], 'documents_missing': ['car'], 'cars': cars},
    };

void main() {
  test('contrôles du véhicule et pièces demandées', () {
    String? check({String brand = 'PEUGEOT', String model = '508', String plate = 'AB-123-CD', int? type = 1, String seats = ''}) => carError(brand: brand, model: model, plate: plate, vehicleTypeId: type, seats: seats);
    expect(check(), isNull);
    expect(check(brand: ' '), 'Indiquez la marque et le modèle.');
    expect(check(plate: 'AB'), 'Indiquez l’immatriculation.');
    expect(check(type: null), 'Choisissez la catégorie du véhicule.');
    expect(check(seats: '40'), 'Nombre de places invalide.');
    expect(carDocuments(rental: false).map((d) => d.kind), ['car_registration', 'car_insurance', 'car_picture']);
    expect(carDocuments(rental: true).last.kind, 'car_rental_contract');
  });

  test('profil : véhicules et pièces reprises', () {
    final car = DriverProfile.fromJson(profileJson(cars: [carJson(documents: [{'id': 3, 'kind': 'car_picture', 'filename': 'photo.jpg', 'byte_size': 1000}])])).cars.single;
    expect(car.name, 'PEUGEOT 508');
    expect(car.motor, 'hybrid');
    expect(car.documents.single.kind, 'car_picture');
    expect(car.validated, isFalse);
  });

  Future<List<http.Request>> pump(WidgetTester tester, Widget Function(DriverProfile) screen, Map<String, dynamic> profile, {Map<String, dynamic>? afterSave}) async {
    final sent = <http.Request>[];
    var current = profile;
    final client = ApiClient(
      baseUrl: 'http://api',
      store: MemorySessionStore()..value = const StoredSession(token: 't', refreshToken: 'r', sessionId: 1),
      client: MockClient((request) async {
        sent.add(request);
        final path = request.url.path;
        if (path == '/api/v1/vehicle_types') {
          return json([{'id': 1, 'name': 'Berline', 'passenger_capacity': 4}]);
        }
        if (path == '/api/v1/profile/cars' && request.method == 'POST') {
          current = afterSave ?? current;
          return json(carJson(), 201);
        }
        if (request.method == 'POST') return json({'id': 9}, 201);
        return json(current);
      }),
    );
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MultiProvider(
      providers: [Provider.value(value: DriverApi(client)), Provider<DocumentPicker>.value(value: FakePicker())],
      child: MaterialApp(home: screen(DriverProfile.fromJson(profile))),
    ));
    await tester.pumpAndSettle();
    return sent;
  }

  testWidgets('liste : véhicule avec les documents encore à fournir, et ajout', (tester) async {
    await pump(tester, (p) => RecruitmentCarsScreen(profile: p), profileJson(cars: [carJson()]));
    expect(find.text('PEUGEOT 508'), findsOneWidget);
    expect(find.text('AB-123-CD · Berline'), findsOneWidget);
    expect(find.text('3 documents à fournir'), findsOneWidget);
    expect(find.text('Ajouter un autre véhicule'), findsOneWidget);
  });

  testWidgets('dossier figé (5/5) : le véhicule reste modifiable et ajoutable', (tester) async {
    final locked = profileJson(cars: [carJson()]);
    (locked['driver'] as Map<String, dynamic>)['locked'] = true;
    (locked['driver'] as Map<String, dynamic>)['validation_status'] = 'validated_awaiting';
    await pump(tester, (p) => RecruitmentCarsScreen(profile: p), locked);
    expect(find.text('Ajouter un autre véhicule'), findsOneWidget);
  });

  testWidgets('liste vide : invite à ajouter le véhicule', (tester) async {
    await pump(tester, (p) => RecruitmentCarsScreen(profile: p), profileJson());
    expect(find.text('Aucun véhicule'), findsOneWidget);
    expect(find.text('Ajouter mon véhicule'), findsOneWidget);
  });

  testWidgets('nouveau véhicule : enregistrement, puis ses documents apparaissent', (tester) async {
    final sent = await pump(tester, (p) => RecruitmentCarScreen(profile: p), profileJson(), afterSave: profileJson(cars: [carJson()]));
    expect(find.textContaining('Enregistrez le véhicule pour ajouter'), findsOneWidget);

    await tester.tap(find.text('Enregistrer le véhicule'));
    await tester.pump();
    expect(find.text('Indiquez la marque et le modèle.'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'peugeot');
    await tester.enterText(fields.at(1), '508');
    await tester.enterText(fields.at(2), 'ab-123-cd');
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Berline · 4 passagers').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer le véhicule'));
    await tester.pumpAndSettle();

    final create = sent.firstWhere((r) => r.method == 'POST');
    expect(create.url.path, '/api/v1/profile/cars');
    final body = jsonDecode(create.body) as Map<String, dynamic>;
    expect(body, containsPair('brand', 'peugeot'));
    expect(body, containsPair('vehicle_type_id', 1));
    expect(body, containsPair('motor', 'gas'));
    expect(find.text('Carte grise'), findsOneWidget);
    expect(find.text('Attestation d’assurance'), findsOneWidget);
    expect(find.text('Photo du véhicule'), findsOneWidget);
    expect(find.text('Contrat de location'), findsNothing);
  });

  testWidgets('envoie la carte grise avec l’identifiant du véhicule', (tester) async {
    final sent = await pump(tester, (p) => RecruitmentCarScreen(profile: p, carId: 7), profileJson(cars: [carJson()]));
    await tester.tap(find.text('Ajouter').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir dans la galerie'));
    await tester.pumpAndSettle();
    final upload = sent.firstWhere((r) => r.url.path == '/api/v1/profile/documents');
    expect(upload.body, allOf(contains('car_registration'), contains('name="car_id"'), contains('carte-grise.jpg')));
  });

  testWidgets('véhicule en location : le contrat est demandé', (tester) async {
    await pump(tester, (p) => RecruitmentCarScreen(profile: p, carId: 7), profileJson(cars: [carJson(rental: true, missing: ['car_rental_contract'])]));
    expect(find.text('Contrat de location'), findsOneWidget);
  });

  testWidgets('véhicule validé : seuls couleur, wifi et activation restent modifiables', (tester) async {
    await pump(tester, (p) => RecruitmentCarScreen(profile: p, carId: 7), profileJson(cars: [carJson(validated: true, missing: [])]));
    expect(find.textContaining('Ce véhicule est validé'), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].enabled, isFalse); // marque
    expect(fields[2].enabled, isFalse); // immatriculation
    expect(fields[4].enabled, isNot(isFalse)); // couleur
    expect(find.text('Ajouter'), findsNothing);
    expect(find.text('Supprimer ce véhicule'), findsNothing);
  });
}

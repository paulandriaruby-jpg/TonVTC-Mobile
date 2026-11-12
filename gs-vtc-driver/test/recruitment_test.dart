import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_driver/models/models.dart';
import 'package:gs_vtc_driver/recruitment/recruitment.dart';
import 'package:gs_vtc_driver/widgets/recruitment_card.dart';

Map<String, dynamic> profileJson(String status, {List<String> details = const [], List<String> documents = const []}) => {
      'user': {'first_name': 'Alice', 'last_name': 'Martin', 'email': 'alice@example.com', 'phone': '0612345678'},
      'driver': {'available': true, 'validation_status': status, 'validation_label': 'x', 'details_missing': details, 'documents_missing': documents, 'locked': false},
    };

void main() {
  test('étapes du recrutement : numéro sur 5 et attente de l\'équipe', () {
    expect(validationSteps.map(stepNumber), [2, 3, 4, 5, 5]);
    expect(waitingForTeam('identified'), isFalse);
    expect(waitingForTeam('data_collected'), isFalse);
    expect(waitingForTeam('files_collected'), isTrue);
    expect(waitingForTeam('validated_awaiting'), isTrue);
    expect(missingLabel('vtc_card'), 'Carte professionnelle VTC');
    expect(missingLabel('inconnu'), 'inconnu');
  });

  test('profil : seul un dossier "validé" ouvre les courses', () {
    expect(DriverProfile.fromJson(profileJson('validated')).validated, isTrue);
    expect(DriverProfile.fromJson(profileJson('validated_awaiting')).validated, isFalse);
    expect(DriverProfile.fromJson(profileJson('identified', details: ['iban'], documents: ['car'])).detailsMissing, ['iban']);
    expect(DriverProfile.fromJson({'user': {'first_name': 'A', 'last_name': 'B', 'email': 'a@b.c'}}).validated, isTrue);
  });

  testWidgets('la fiche liste ce qu\'il reste à fournir, ou annonce la vérification', (tester) async {
    Future<void> show(DriverProfile profile) => tester.pumpWidget(MaterialApp(home: Scaffold(body: RecruitmentCard(profile: profile))));

    await show(DriverProfile.fromJson(profileJson('identified', details: ['iban', 'siret'], documents: ['vtc_card', 'car'])));
    expect(find.text('2/5'), findsOneWidget);
    expect(find.text('Compléter vos informations'), findsOneWidget);
    for (final label in ['IBAN', 'SIRET', 'Carte professionnelle VTC', 'Un véhicule avec ses documents']) {
      expect(find.text(label), findsOneWidget);
    }

    await show(DriverProfile.fromJson(profileJson('files_collected')));
    expect(find.text('4/5'), findsOneWidget);
    expect(find.textContaining('Notre équipe vérifie'), findsOneWidget);
    expect(find.text('Il reste à fournir :'), findsNothing);
  });

  testWidgets('dossier figé : les boutons deviennent "Voir" (lecture seule), le véhicule reste accessible', (tester) async {
    final json = profileJson('validated_awaiting');
    (json['driver'] as Map<String, dynamic>)['locked'] = true;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RecruitmentCard(profile: DriverProfile.fromJson(json), onEditDetails: () {}, onEditDocuments: () {}, onEditCars: () {})),
    ));
    expect(find.text('5/5'), findsOneWidget);
    expect(find.text('Voir mes informations'), findsOneWidget);
    expect(find.text('Voir mes documents'), findsOneWidget);
    expect(find.text('Mon véhicule'), findsOneWidget);
    expect(find.text('Compléter mes informations'), findsNothing);
  });

  testWidgets('étape 2/5 : le bouton principal est "Compléter mes informations"', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RecruitmentCard(profile: DriverProfile.fromJson(profileJson('identified', details: ['iban'])), onEditDetails: () {}, onEditDocuments: () {}, onEditCars: () {})),
    ));
    expect(find.text('Compléter mes informations'), findsOneWidget);
    expect(find.text('Mes documents'), findsOneWidget);
    expect(find.text('Mon véhicule'), findsOneWidget);
  });
}

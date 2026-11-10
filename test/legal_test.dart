import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_client/legal/legal.dart';
import 'package:gs_vtc_client/screens/legal_screen.dart';

void main() {
  test('pages légales : mentions, CGV et confidentialité, sur le site', () {
    expect(legalPages.map((p) => p.path), ['/mentions-legales', '/cgv', '/confidentialite']);
  });

  testWidgets('écran des informations légales', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LegalScreen()));
    expect(find.text('Mentions légales'), findsOneWidget);
    expect(find.text('Conditions générales de vente'), findsOneWidget);
    expect(find.text('Politique de confidentialité'), findsOneWidget);
  });

  testWidgets('la case d\'acceptation se coche et affiche les liens', (tester) async {
    var accepted = false;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) => Scaffold(body: TermsCheckbox(value: accepted, onChanged: (v) => setState(() => accepted = v)))),
    ));
    expect(find.textContaining('conditions générales de vente', findRichText: true), findsOneWidget);
    expect(find.textContaining('politique de confidentialité', findRichText: true), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(accepted, isTrue);
  });
}

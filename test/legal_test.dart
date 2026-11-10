import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_driver/legal/legal.dart';
import 'package:gs_vtc_driver/screens/legal_screen.dart';

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
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Le texte de l'app reste naturel : uniquement des caracteres qu'on tape au clavier (lettres accentuees francaises,
// euro, degre). Pas de tiret long, de guillemets francais, d'apostrophe typographique, de fleche, d'espace insecable...
final _allowed = RegExp('[\u0000-~]|[àâäçéèêëîïôöùûüÿÀÂÄÇÉÈÊËÎÏÔÖÙÛÜŸ€°²]');

void main() {
  test('le code ne contient que des caracteres presents sur un clavier', () {
    final offenders = <String>[];
    for (final folder in ['lib', 'test']) {
      for (final file in Directory(folder).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final bad = lines[i].runes.map(String.fromCharCode).where((c) => !_allowed.hasMatch(c)).toSet();
          if (bad.isNotEmpty) offenders.add('${file.path}:${i + 1} ${bad.map((c) => 'U+${c.runes.first.toRadixString(16).toUpperCase().padLeft(4, '0')}').join(' ')}');
        }
      }
    }
    expect(offenders.take(20).toList(), isEmpty);
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Regles de style TonVTC : jamais de degrade, et des arrondis de 8 px au plus (les cercles passent par CircleAvatar
// ou BoxShape.circle, pas par un rayon).
final _gradient = RegExp(r'\b(Linear|Radial|Sweep)Gradient\b');
final _radius = RegExp(r'Radius\.circular\((\d+(?:\.\d+)?)\)');

List<String> _offenders(bool Function(String line) check) {
  final offenders = <String>[];
  for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (check(lines[i])) offenders.add('${file.path}:${i + 1}');
    }
  }
  return offenders;
}

void main() {
  test('aucun degrade', () => expect(_offenders(_gradient.hasMatch), isEmpty));
  test('arrondis de 8 px au plus', () => expect(_offenders((line) => _radius.allMatches(line).any((m) => double.parse(m.group(1)!) > 8)), isEmpty));
}

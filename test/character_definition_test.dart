import 'package:flutter_test/flutter_test.dart';
import 'package:textify/artifact.dart';
import 'package:textify/character_definition.dart';

void main() {
  group('CharacterDefinition', () {
    test('constructor creates instance with correct properties', () {
      final charDef = CharacterDefinition(
        character: 'A',
        enclosures: 1,
        isLetter: true,
        matrices: [Artifact(10, 10)],
      );

      expect(charDef.character, 'A');
      expect(charDef.enclosures, 1);
      expect(charDef.isLetter, true);
      expect(charDef.isDigit, false);
      expect(charDef.matrices.length, 1);
    });

    test('fromJson creates correct instance', () {
      final json = {
        'character': 'B',
        'enclosures': 2,
        'lineLeft': true,
        'lineRight': false,
        'isLetter': true,
        'isAmount': false,
        'isDate': false,
        'isDigit': false,
        'isPunctuation': false,
        'matrices': [Artifact(5, 5).toJson()],
      };

      final charDef = CharacterDefinition.fromJson(json);

      expect(charDef.character, 'B');
      expect(charDef.enclosures, 2);
      expect(charDef.lineLeft, true);
      expect(charDef.lineRight, false);
      expect(charDef.matrices.length, 1);
    });

    test('toJson serializes correctly', () {
      final charDef = CharacterDefinition(
        character: 'C',
        isPunctuation: true,
      );

      final json = charDef.toJson();

      expect(json['character'], 'C');
      expect(json['isPunctuation'], true);
      expect(json['isLetter'], false);
    });

    test('fromJsonString and toJsonString work correctly', () {
      final original = CharacterDefinition(
        character: 'D',
        isDigit: true,
        matrices: [Artifact(8, 8)],
      );

      final jsonString = original.toJsonString();
      final decoded = CharacterDefinition.fromJsonString(jsonString);

      expect(decoded.character, original.character);
      expect(decoded.isDigit, original.isDigit);
      expect(decoded.matrices.length, original.matrices.length);
    });
  });
}

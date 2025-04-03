import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:textify/artifact.dart';
import 'package:textify/character_definitions.dart';

void main() {
  group('CharacterDefinitions', () {
    test('constructor creates empty definitions list', () {
      final definitions = CharacterDefinitions();
      expect(definitions.count, 0);
      expect(definitions.definitions, isEmpty);
    });

    test('addDefinition adds a definition', () {
      final CharacterDefinitions definitions = CharacterDefinitions();
      final CharacterDefinition charDef = CharacterDefinition(character: 'A');

      definitions.addDefinition(charDef);

      expect(definitions.count, 1);
      expect(definitions.definitions.first, charDef);
    });

    test('getDefinition returns correct definition', () {
      final definitions = CharacterDefinitions();
      final charDefA = CharacterDefinition(character: 'A');
      final charDefB = CharacterDefinition(character: 'B');

      definitions.addDefinition(charDefA);
      definitions.addDefinition(charDefB);

      expect(definitions.getDefinition('A'), charDefA);
      expect(definitions.getDefinition('B'), charDefB);
      expect(definitions.getDefinition('C'), isNull);
      final Artifact artifactOfA = definitions.getMatrix('A', 0);
      expect(artifactOfA.gridToStrings(), []);
    });

    test('supportedCharacters returns all character lists combined', () {
      final definitions = CharacterDefinitions();
      final allChars = definitions.supportedCharacters;

      expect(allChars, containsAll(letterUpperCase));
      expect(allChars, containsAll(letterLowerCase));
      expect(allChars, containsAll(digits));
    });

    test('upsertTemplate adds new definition when character not found', () {
      final definitions = CharacterDefinitions();
      final artifact = Artifact(5, 5);

      final result = definitions.upsertTemplate('Arial', 'X', artifact);

      expect(result, true);
      expect(definitions.count, 1);
      expect(definitions.getDefinition('X'), isNotNull);
      expect(definitions.getDefinition('X')!.matrices.first, artifact);
      expect(definitions.getDefinition('X')!.matrices.first.font, 'Arial');
    });

    test('_sortDefinitions sorts definitions alphabetically', () {
      final definitions = CharacterDefinitions();
      definitions.addDefinition(CharacterDefinition(character: 'C'));
      definitions.addDefinition(CharacterDefinition(character: 'A'));
      definitions.addDefinition(CharacterDefinition(character: 'B'));

      // Access private method through toJsonString which calls _sortDefinitions
      definitions.toJsonString();

      expect(definitions.definitions[0].character, 'A');
      expect(definitions.definitions[1].character, 'B');
      expect(definitions.definitions[2].character, 'C');
    });

    test('toJsonString returns properly formatted JSON', () {
      final definitions = CharacterDefinitions();
      definitions.addDefinition(CharacterDefinition(character: 'X'));

      final jsonString = definitions.toJsonString();
      final decoded = jsonDecode(jsonString);

      expect(decoded, isA<Map<String, dynamic>>());
      expect(decoded['templates'], isA<List>());
      expect(decoded['templates'].length, 1);
      expect(decoded['templates'][0]['character'], 'X');
    });
  });
}

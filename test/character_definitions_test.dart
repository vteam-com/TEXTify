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

      // insert a fake character
      final bool result2 = definitions.upsertTemplate(
        'Courier',
        '😭',
        artifact,
      );
      expect(result2, true);
      // Again
      final bool result3 = definitions.upsertTemplate(
        'Courier',
        '😭',
        artifact,
      );
      expect(result3, false);
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

    test('loadDefinitions throws exception on failure', () async {
      final definitions = CharacterDefinitions();

      // Mock the asset bundle to throw an error
      TestWidgetsFlutterBinding.ensureInitialized();
      // Attempt to load definitions and expect an exception
      expect(
        () => definitions.loadDefinitions('invalid/path.json'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to load character definitions'),
          ),
        ),
      );
    });

    test(
      'upsertTemplate adds new matrix to existing definition when font is new',
      () {
        final definitions = CharacterDefinitions();
        // Create a character definition with an empty matrices list
        final charDef = CharacterDefinition(
          character: 'A',
          matrices: [], // Explicitly initialize with an empty list
        );
        definitions.addDefinition(charDef);

        final artifact1 = Artifact(5, 5);
        final result1 = definitions.upsertTemplate('Arial', 'A', artifact1);

        // Should return false as we're updating an existing definition
        expect(result1, false);
        // Should have added the matrix to the existing definition
        expect(definitions.getDefinition('A')!.matrices.length, 1);
        expect(definitions.getDefinition('A')!.matrices.first, artifact1);
        expect(definitions.getDefinition('A')!.matrices.first.font, 'Arial');

        // Add a second matrix with a different font
        final artifact2 = Artifact(6, 6);
        final result2 = definitions.upsertTemplate('Roboto', 'A', artifact2);

        // Should return false as we're updating an existing definition
        expect(result2, false);
        // Should have added the second matrix to the existing definition
        expect(definitions.getDefinition('A')!.matrices.length, 2);
        expect(definitions.getDefinition('A')!.matrices[1], artifact2);
        expect(definitions.getDefinition('A')!.matrices[1].font, 'Roboto');
      },
    );

    test('getMatrix returns correct matrix at specified index', () {
      final definitions = CharacterDefinitions();
      final artifact1 = Artifact(5, 5);
      final artifact2 = Artifact(6, 6);

      final charDef = CharacterDefinition(
        character: 'A',
        matrices: [artifact1, artifact2],
      );

      definitions.addDefinition(charDef);

      // Test retrieving the first matrix
      final result1 = definitions.getMatrix('A', 0);
      expect(result1, artifact1);

      // Test retrieving the second matrix
      final result2 = definitions.getMatrix('A', 1);
      expect(result2, artifact2);
    });
  });

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
      final charDef = CharacterDefinition(character: 'C', isPunctuation: true);

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

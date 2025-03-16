import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:textify/artifact.dart';
import 'package:textify/character_definition.dart';
export 'package:textify/character_definition.dart';

/// Manages a collection of character definitions used for text processing.
///
/// This class provides methods to load, manipulate, and retrieve character
/// definitions, which are used to represent the visual appearance of characters
/// in different fonts or styles.
class CharacterDefinitions {
  /// The list of character definitions.
  List<CharacterDefinition> _definitions = const [];

  /// Returns the number of character definitions.
  int get count => _definitions.length;

  /// Adds a new character definition to the collection.
  ///
  /// [definition] The character definition to add.
  void addDefinition(final CharacterDefinition definition) {
    _definitions.add(definition);
  }

  /// Returns an unmodifiable list of all character definitions.
  List<CharacterDefinition> get definitions {
    return List.unmodifiable(_definitions);
  }

  /// Parses character definitions from a JSON string.
  ///
  /// [jsonString] A JSON string containing character definitions.
  void fromJsonString(final String jsonString) {
    final dynamic jsonObject = jsonDecode(jsonString);
    final List<dynamic> jsonList = jsonObject['templates'];
    _definitions =
        jsonList.map((json) => CharacterDefinition.fromJson(json)).toList();
  }

  /// Retrieves a specific character definition.
  ///
  /// [character] The character to find the definition for.
  ///
  /// Returns the [CharacterDefinition] for the specified character,
  /// or null if not found.
  CharacterDefinition? getDefinition(final String character) {
    try {
      return _definitions.firstWhere((t) => t.character == character);
    } catch (e) {
      return null;
    }
  }

  /// Returns a list of all supported characters.
  List<String> get supportedCharacters {
    return letterUpperCase +
        letterLowerCase +
        digits +
        punctuationMarks +
        otherCharacters;
  }

  /// Retrieves a specific [Artifact] for a given character.
  ///
  /// This method fetches a character definition and returns the matrix at the specified index.
  /// If the character definition doesn't exist or the index is out of bounds, an empty matrix is returned.
  ///
  /// Parameters:
  /// - [character]: A [String] representing the character for which to retrieve the matrix.
  ///   This should be a single character, typically.
  /// - [matricesIndex]: An [int] specifying the index of the desired matrix within the character's
  ///   definition. Different indices may represent variations or different representations of the character.
  ///
  /// Returns:
  /// - A [Artifact] object representing the character at the specified index.
  /// - Returns an empty [Artifact] if:
  ///   - No definition is found for the character.
  ///   - The matricesIndex is negative.
  ///   - The matricesIndex is out of bounds for the character's matrices.
  ///
  Artifact getMatrix(
    final String character,
    final int matricesIndex,
  ) {
    final CharacterDefinition? definition = getDefinition(character);
    if (definition == null ||
        matricesIndex < 0 ||
        matricesIndex >= definition.matrices.length) {
      return Artifact();
    }
    return definition.matrices[matricesIndex];
  }

  /// Loads character definitions from a JSON file.
  ///
  /// [pathToAssetsDefinition] The path to the JSON file containing definitions.
  ///
  /// Returns a ```Future<CharacterDefinitions>``` once loading is complete.
  ///
  /// Throws an exception if loading fails.
  Future<CharacterDefinitions> loadDefinitions([
    final String pathToAssetsDefinition =
        'packages/textify/assets/matrices.json',
  ]) async {
    try {
      String jsonString = await rootBundle.loadString(pathToAssetsDefinition);
      fromJsonString(jsonString);
      return this;
    } catch (e) {
      throw Exception('Failed to load character definitions: $e');
    }
  }

  /// Sorts character definitions alphabetically by character.
  void _sortDefinitions() {
    _definitions.sort(
      (final CharacterDefinition a, final CharacterDefinition b) =>
          a.character.compareTo(b.character),
    );
  }

  /// Converts character definitions to a JSON string.
  ///
  /// Returns a JSON string representation of all character definitions.
  String toJsonString() {
    _sortDefinitions();

    final Map<String, dynamic> matricesMap = {
      'templates': definitions
          .map((final CharacterDefinition template) => template.toJson())
          .toList(),
    };

    return jsonEncode(matricesMap);
  }

  /// Updates or inserts a template matrix for a given character and font.
  ///
  /// If a definition for the character doesn't exist, a new one is created.
  /// If a matrix for the given font already exists, it is updated; otherwise, it's added.
  ///
  /// [font] The font name for the matrix.
  /// [character] The character this matrix represents.
  /// [matrix] The Matrix object containing the character's pixel data.
  bool upsertTemplate(
    final String font,
    final String character,
    final Artifact matrix,
  ) {
    matrix.font = font;
    final CharacterDefinition? found = getDefinition(character);
    if (found == null) {
      final CharacterDefinition newDefinition = CharacterDefinition(
        character: character,
        matrices: [matrix],
      );
      _definitions.add(newDefinition);
      return true;
    } else {
      final int existingMatrixIndex =
          found.matrices.indexWhere((final Artifact m) => m.font == font);

      if (existingMatrixIndex == -1) {
        found.matrices.add(matrix);
      } else {
        found.matrices[existingMatrixIndex] = matrix;
      }
      return false;
    }
  }
}

/// All Characters representing Letters in upper case
const List<String> letterUpperCase = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
];

/// All Characters representing Letters in lower case
const List<String> letterLowerCase = [
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i',
  'j',
  'k',
  'l',
  'm',
  'n',
  'o',
  'p',
  'q',
  'r',
  's',
  't',
  'u',
  'v',
  'w',
  'x',
  'y',
  'z',
];

/// All Characters representing Digits
const List<String> digits = [
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
];

/// All Characters representing punctuation
const List<String> punctuationMarks = [
  ' ', // Space
  '.', // Period
  ',', // Comma
  '?', // Question Mark
  '!', // Exclamation Mark
  ':', // Colon
  ';', // Semicolon
  "'", // Apostrophe
  '"', // Quotation Marks
  '(', // Parentheses
  ')', // Parentheses
  '{', // Brackets Curly open
  '}', // Brackets Curly close
  '[', // Brackets Square open
  ']', // Brackets Square close
  '<', // Brackets Angle open
  '>', // Brackets Angle close
  '-', // Dash
];

/// All Characters not digits, letters or punctuation
const List<String> otherCharacters = [
  '/', // Slash
  '\\', // Back Slash
  '+', // Plus (the minus is a dash punctuation)
  '=', // Back Slash
  '#', // Hash
  '\$', // Dollar
  '&', //
  '*', //
  '@', //
];

/// This library is part of the Textify package.
/// Provides serialization and display extensions for Artifact:
/// text conversion, grid printing, JSON output, and character descriptions.
library;

import 'package:textify/artifact.dart';
import 'package:textify/char_utils.dart';
import 'package:textify/constants.dart';

/// Extension that adds serialization and display methods to [Artifact].
extension ArtifactSerializeExt on Artifact {
  /// Returns a human-readable description of the matching character.
  String get matchingCharacterDescription {
    String description = '"$matchingCharacter"';

    if (isLetter(matchingCharacter)) {
      if (isUpperCase(matchingCharacter)) {
        description = CharacterLabels.upperCase;
      } else {
        description = CharacterLabels.lowerCase;
      }
      description += ' "${matchingCharacter.toUpperCase()}"';
    }

    if (isDigit(matchingCharacter)) {
      description =
          '${CharacterLabels.digit} "$matchingCharacter"${matchingCharacter == '0' ? ' Zero' : ''}';
    }
    return description;
  }

  /// Converts the matrix to a text representation.
  String toText({final String onChar = '#', final bool forCode = false}) {
    return gridToString(forCode: forCode, onChar: onChar);
  }

  /// Converts the matrix to a string representation.
  String gridToString({
    final bool forCode = false,
    final String onChar = '#',
    final String offChar = '.',
  }) {
    final List<String> list = gridToStrings(onChar: onChar, offChar: offChar);
    return forCode ? '"${list.join('",\n"')}"' : list.join('\n');
  }

  /// Converts the matrix to a list of strings.
  ///
  /// Each string represents a row in the matrix.
  List<String> gridToStrings({
    final String onChar = '#',
    final String offChar = '.',
  }) {
    final List<String> result = [];

    for (int row = 0; row < rows; row++) {
      String rowString = '';
      for (int col = 0; col < cols; col++) {
        rowString += cellGet(col, row) ? onChar : offChar;
      }

      result.add(rowString);
    }

    return result;
  }

  /// Converts the Artifact object to a JSON-serializable Map.
  Map<String, dynamic> toJson() {
    return {
      'font': font,
      'rows': rows,
      'cols': cols,
      'data': matrix.map((_ /* row */) {
        return List.generate(rows, (y) {
          return List.generate(cols, (x) => cellGet(x, y) ? '#' : '.').join();
        });
      }).toList(),
    };
  }
}

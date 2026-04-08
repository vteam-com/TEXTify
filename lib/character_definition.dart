/// This library is part of the Textify package.
/// It provides character definition functionality for OCR processing.
library;

import 'dart:convert';
import 'dart:math';

import 'package:textify/artifact.dart';
import 'package:textify/artifact_serialize.dart';

/// A class that defines the characteristics and properties of a single character for OCR processing.
///
/// The [CharacterDefinition] class stores various attributes of a character including its visual
/// representation through template artifacts, structural properties like enclosures, and categorical information
/// such as whether it's a letter, digit, or punctuation mark.
///
/// Example:
/// ```dart
/// final charDef = CharacterDefinition(
///   character: 'A',
///   isLetter: true,
///   matrices: [Artifact(...)],
/// );
/// ```
///
/// Key features:
/// * Supports JSON serialization/deserialization
/// * Stores multiple template artifacts of the character
/// * Tracks character properties like enclosures and line presence
/// * Categorizes characters (letter, digit, punctuation, etc.)
/// * Maintains standard template dimensions (60x40)
///
/// This class is fundamental to the Textify OCR system, providing the template
/// definitions used for character recognition and matching.
class CharacterDefinition {
  /// Creates a new [CharacterDefinition] instance.
  ///
  /// Parameters:
  /// - [character]: The character this definition represents. This parameter is required.
  /// - [enclosures]: The number of enclosures (e.g., brackets, parentheses) associated with this character. Defaults to 0.
  /// - [isAmount]: Indicates whether this character is typically used in monetary amounts. Defaults to false.
  /// - [isDate]: Indicates whether this character is commonly used in date representations. Defaults to false.
  /// - [isDigit]: Indicates whether this character is a numerical digit. Defaults to false.
  /// - [isLetter]: Indicates whether this character is an alphabetic letter. Defaults to false.
  /// - [isPunctuation]: Indicates whether this character is a punctuation mark. Defaults to false.
  /// - [lineLeft]: Indicates whether this character typically has a line to its left (e.g., in handwriting). Defaults to false.
  /// - [lineRight]: Indicates whether this character typically has a line to its right (e.g., in handwriting). Defaults to false.
  /// - [matrices]: A list of matrices representing the visual pattern of this character. Defaults to an empty list.
  ///
  /// All parameters except [character] are optional and have default values.
  CharacterDefinition({
    required this.character,
    this.enclosures = 0,
    this.isAmount = false,
    this.isDate = false,
    this.isDigit = false,
    this.isLetter = false,
    this.isPunctuation = false,
    this.lineLeft = false,
    this.lineRight = false,
    this.matrices = const [],
  });

  /// Creates a [CharacterDefinition] from a JSON map.
  ///
  /// Parameters:
  /// - [json] is a map containing key-value pairs representing the properties
  /// of a CharacterDefinition. The keys should match the property names of
  /// the CharacterDefinition class, and the values should be of the appropriate types.
  ///
  /// Returns a new instance of [CharacterDefinition] populated with the data from [json].
  factory CharacterDefinition.fromJson(final Map<String, dynamic> json) {
    return CharacterDefinition(
      character: json['character'] as String,
      enclosures: json['enclosures'] as int,
      lineLeft: json['lineLeft'] as bool,
      lineRight: json['lineRight'] as bool,
      isLetter: json['isLetter'] as bool,
      isAmount: json['isAmount'] as bool,
      isDate: json['isDate'] as bool,
      isDigit: json['isDigit'] as bool,
      isPunctuation: json['isPunctuation'] as bool,
      matrices: (json['matrices'] as List)
          .map((m) => Artifact.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Creates a [CharacterDefinition] from a JSON string.
  ///
  /// [jsonString] is a String containing a JSON representation of a CharacterDefinition.
  /// The JSON structure should match the properties of the CharacterDefinition class.
  ///
  /// This factory method first decodes the JSON string into a Map using [jsonDecode],
  /// then delegates to [CharacterDefinition.fromJson] to create the instance.
  ///
  /// Returns a new instance of [CharacterDefinition] populated with the data from [jsonString].
  ///
  /// Throws a [FormatException] if the string is not valid JSON.
  /// Throws a [TypeError] if the JSON structure doesn't match the expected format.
  factory CharacterDefinition.fromJsonString(final String jsonString) {
    return CharacterDefinition.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  /// The height of the character template.
  static const int templateHeight = 60;

  /// The width of the character template.
  static const int templateWidth = 40;

  /// The character being defined.
  final String character;

  /// The number of enclosures for this character.
  final int enclosures;

  /// Indicates if this character is used in monetary amounts.
  final bool isAmount;

  /// Indicates if this character is commonly used in date representations.
  final bool isDate;

  /// Indicates if this character is a numerical digit.
  final bool isDigit;

  /// Indicates if this character is an alphabetic letter.
  final bool isLetter;

  /// Indicates if this character is a punctuation mark.
  final bool isPunctuation;

  /// Indicates if the character has a left vertical line as part of its shape.
  final bool lineLeft;

  /// Indicates if the character has a right vertical line as part of its shape.
  final bool lineRight;

  /// List of matrices representing this character's visual pattern.
  final List<Artifact> matrices;

  /// Cached average column histogram (pixel count per column) across all templates.
  List<double>? _cachedColHistogram;

  /// Cached average row histogram (pixel count per row) across all templates.
  List<double>? _cachedRowHistogram;

  /// Returns the average column histogram across all template matrices.
  ///
  /// Each entry is the average pixel count at that column position.
  /// Lazily computed and cached.
  List<double> get averageColHistogram {
    return _cachedColHistogram ??= _computeAverageHistogram(true);
  }

  /// Returns the average row histogram across all template matrices.
  ///
  /// Each entry is the average pixel count at that row position.
  /// Lazily computed and cached.
  List<double> get averageRowHistogram {
    return _cachedRowHistogram ??= _computeAverageHistogram(false);
  }

  /// Computes the average histogram across all template matrices.
  ///
  /// When [isColumn] is true, returns column-wise pixel counts (per-column).
  /// When false, returns row-wise pixel counts (per-row).
  List<double> _computeAverageHistogram(bool isColumn) {
    if (matrices.isEmpty) {
      return const [];
    }

    final int size = isColumn ? templateWidth : templateHeight;
    final List<double> avgHist = List<double>.filled(size, 0);

    for (final Artifact m in matrices) {
      for (int i = 0; i < size; i++) {
        int count = 0;
        if (isColumn) {
          for (int y = 0; y < m.rows; y++) {
            if (i < m.cols && m.cellGet(i, y)) {
              count++;
            }
          }
        } else {
          for (int x = 0; x < m.cols; x++) {
            if (i < m.rows && m.cellGet(x, i)) {
              count++;
            }
          }
        }
        avgHist[i] += count;
      }
    }

    for (int i = 0; i < size; i++) {
      avgHist[i] /= matrices.length;
    }

    return avgHist;
  }

  /// Computes histogram similarity between this template and an input artifact.
  ///
  /// Returns a value between 0.0 and 1.0, where 1.0 is a perfect match.
  /// Uses L1 (Manhattan) distance normalized by the max possible distance.
  double histogramSimilarity(List<int> inputColHist, List<int> inputRowHist) {
    final List<double> templateCol = averageColHistogram;
    final List<double> templateRow = averageRowHistogram;

    if (templateCol.isEmpty || templateRow.isEmpty) {
      return 0.0;
    }

    double colDistance = 0;
    double colMax = 0;
    final int colLen = min(inputColHist.length, templateCol.length);
    for (int i = 0; i < colLen; i++) {
      colDistance += (inputColHist[i] - templateCol[i]).abs();
      colMax += max(inputColHist[i].toDouble(), templateCol[i]);
    }

    double rowDistance = 0;
    double rowMax = 0;
    final int rowLen = min(inputRowHist.length, templateRow.length);
    for (int i = 0; i < rowLen; i++) {
      rowDistance += (inputRowHist[i] - templateRow[i]).abs();
      rowMax += max(inputRowHist[i].toDouble(), templateRow[i]);
    }

    final double totalMax = colMax + rowMax;
    if (totalMax == 0) {
      return 0.0;
    }

    return 1.0 - ((colDistance + rowDistance) / totalMax);
  }

  /// Converts this [CharacterDefinition] to a JSON map.
  ///
  /// Returns a ```Map<String, dynamic>``` representation of the CharacterDefinition,
  /// where each key is a property name and each value is the corresponding property value.
  Map<String, dynamic> toJson() {
    return {
      'character': character,
      'enclosures': enclosures,
      'isAmount': isAmount,
      'isDate': isDate,
      'isDigit': isDigit,
      'isLetter': isLetter,
      'isPunctuation': isPunctuation,
      'lineLeft': lineLeft,
      'lineRight': lineRight,
      'matrices': matrices.map((m) => m.toJson()).toList(),
    };
  }

  /// Converts this [CharacterDefinition] to a JSON string.
  ///
  /// Returns a String containing a JSON representation of the CharacterDefinition.
  /// This method uses [toJson] to create a map and then encodes it to a JSON string.
  ///
  /// Example:
  /// ```dart
  /// final charDef = CharacterDefinition(character: 'A', isLetter: true);
  /// final jsonString = charDef.toJsonString();
  /// print(jsonString); // Prints the JSON representation as a string
  /// ```
  String toJsonString() => jsonEncode(toJson());
}

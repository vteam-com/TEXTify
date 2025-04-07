/// This library is part of the Textify package.
/// It contains the ScoreMatch class used to track evaluation scores
/// when matching artifacts against character definition templates.
library;

/// Keep track of evaluation score of Artifacts against CharacterDefinition templates
class ScoreMatch {
  /// Constructs a [ScoreMatch] object with the provided [character], [matrixIndex], and [score].
  ///
  /// The [character] represents the matched character, the [matrixIndex] is the index of the
  /// matching template matrices, and the [score] is the final score in percentage (0..1).
  ScoreMatch({
    this.character = '',
    this.matrixIndex = -1,
    this.score = 0.0,
  });

  /// Character matched
  final String character;

  /// Index of the matching template matrices
  final int matrixIndex;

  /// final score in percentage 0..1
  final double score;
}

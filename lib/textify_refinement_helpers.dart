part of 'textify.dart';

/// Resolves near-ties by preferring candidates with stronger structure matches.
///
/// This helps disambiguate lookalikes such as `B` vs `D` when pixel distance
/// is very close but one candidate better matches enclosure/line features.
void _applyStructuralTieBreak(
  List<ScoreMatch> scores,
  Map<String, double> structuralMatchByCharacter,
) {
  if (scores.length < Textify._minimumTieBreakCandidates) {
    return;
  }

  final double bestScore = scores.first.score;
  final int topCategory = _characterCategory(scores.first.character);
  final bool topIsUppercase = isUppercaseLetter(scores.first.character);
  final bool topIsLowercase = isLowercaseLetter(scores.first.character);
  int bestIndex = 0;
  double bestStructural =
      structuralMatchByCharacter[scores.first.character] ?? 0;

  for (int i = 1; i < scores.length; i++) {
    final ScoreMatch candidate = scores[i];
    if ((bestScore - candidate.score) > Textify._structuralTieBreakDelta) {
      break;
    }

    final int category = _characterCategory(candidate.character);
    if (category != topCategory) {
      continue;
    }
    if (category == Textify._characterCategoryLetter &&
        !_matchesLetterCase(
          candidate.character,
          topIsUppercase,
          topIsLowercase,
        )) {
      continue;
    }

    final double structural =
        structuralMatchByCharacter[candidate.character] ?? 0;
    final bool strongerStructural =
        structural > (bestStructural + Textify._scoreEqualityTolerance);
    final bool sameStructuralBetterScore =
        (structural - bestStructural).abs() <=
            Textify._scoreEqualityTolerance &&
        candidate.score > scores[bestIndex].score;
    if (strongerStructural || sameStructuralBetterScore) {
      bestIndex = i;
      bestStructural = structural;
    }
  }

  if (bestIndex == 0) {
    return;
  }

  final ScoreMatch selected = scores.removeAt(bestIndex);
  scores.insert(0, selected);
}

/// Returns true when candidate letter casing is compatible with top score.
bool _matchesLetterCase(
  String candidate,
  bool topIsUppercase,
  bool topIsLowercase,
) {
  if (topIsUppercase) {
    return isUppercaseLetter(candidate);
  }
  if (topIsLowercase) {
    return isLowercaseLetter(candidate);
  }
  return true;
}

/// Classifies recognized candidates into broad groups for tie-break safety.
int _characterCategory(String character) {
  if (isLetter(character)) {
    return Textify._characterCategoryLetter;
  }
  if (isDigit(character)) {
    return Textify._characterCategoryDigit;
  }
  return Textify._characterCategoryOther;
}

/// Prefers `R/r` over `P/p` when a lower-right stroke is detected.
void _promoteRWhenLowerRightStroke(List<ScoreMatch> scores) {
  if (scores.isEmpty) {
    return;
  }

  final int pIndex = scores.indexWhere(
    (score) => score.character == 'P' || score.character == 'p',
  );
  final int rIndex = scores.indexWhere(
    (score) => score.character == 'R' || score.character == 'r',
  );

  if (pIndex != 0 || rIndex < 0) {
    return;
  }

  final double pScore = scores[pIndex].score;
  final double rScore = scores[rIndex].score;
  if ((pScore - rScore) <= Textify._lowerRightStrokeSwapDelta) {
    final ScoreMatch r = scores.removeAt(rIndex);
    scores.insert(0, r);
  }
}

/// Prefers `u` when a narrow lowercase `m` candidate is likely over-segmented.
void _promoteUWhenNarrowLowercaseM(
  List<ScoreMatch> scores,
  double inputAspectRatio,
  int stemCount,
) {
  if (scores.isEmpty) {
    return;
  }

  final int mIndex = scores.indexWhere((score) => score.character == 'm');
  final int uIndex = scores.indexWhere((score) => score.character == 'u');

  if (mIndex != 0 || uIndex < 0) {
    return;
  }

  if (stemCount <= Textify._lowercaseMToUStemThreshold) {
    final ScoreMatch u = scores.removeAt(uIndex);
    scores.insert(0, u);
    return;
  }

  if (inputAspectRatio >= Textify._lowercaseMToUAspectRatioThreshold) {
    return;
  }

  final double mScore = scores[mIndex].score;
  final double uScore = scores[uIndex].score;
  if ((mScore - uScore) <= Textify._lowercaseMUScoreDelta) {
    final ScoreMatch u = scores.removeAt(uIndex);
    scores.insert(0, u);
  }
}

/// Prefers a letter over punctuation/symbol when scores are close.
///
/// Text images overwhelmingly contain letters. When a bracket or symbol
/// wins by a tiny margin over a letter with matching structural features,
/// the letter is almost always the correct reading.
void _promoteLetterOverPunctuation(List<ScoreMatch> scores) {
  if (scores.length < Textify._minimumTieBreakCandidates) {
    return;
  }

  final ScoreMatch top = scores.first;
  if (isLetter(top.character) || isDigit(top.character)) {
    return;
  }

  for (int i = 1; i < scores.length; i++) {
    final ScoreMatch candidate = scores[i];
    if ((top.score - candidate.score) > Textify._letterOverPunctuationDelta) {
      break;
    }
    if (isLetter(candidate.character)) {
      final ScoreMatch letter = scores.removeAt(i);
      scores.insert(0, letter);
      return;
    }
  }
}

double? _scoreForCharacter(List<ScoreMatch> scores, String character) {
  for (final ScoreMatch score in scores) {
    if (score.character == character) {
      return score.score;
    }
  }
  return null;
}

/// Measures how much of an artifact's foreground lies in its bottom third.
///
/// This helps distinguish shapes like `E` and `F`, where the lower stroke
/// may be faint or absent in small serif renderings.
double _lowerThirdDensity(Artifact artifact) {
  final IntRect content = artifact.getContentRect();
  if (content.isEmpty) {
    return 0;
  }

  final int totalOn = artifact.countOnPixels(rect: content);
  if (totalOn == 0) {
    return 0;
  }

  final int startY = content.top + ((content.height * 2) ~/ 3);
  final IntRect lowerThird = IntRect.fromLTRB(
    content.left,
    startY.clamp(content.top, content.bottom),
    content.right,
    content.bottom,
  );
  if (lowerThird.isEmpty) {
    return 0;
  }

  return artifact.countOnPixels(rect: lowerThird) / totalOn;
}

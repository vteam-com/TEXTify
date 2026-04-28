part of 'textify.dart';

const int _splitPartCount = 2;
const int _structuralMismatchSentinel = 1 << 30;

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
    final double allowedDelta = i == 1 && topIsLowercase
        ? Textify._runnerUpStructuralTieBreakDelta
        : Textify._structuralTieBreakDelta;
    if ((bestScore - candidate.score) > allowedDelta) {
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

/// Splits a weak wide uppercase artifact when its right side is a strong `I`.
void _splitMergedTrailingUppercaseI(Textify instance, Band band) {
  if (!Textify._looksLikeUppercaseProseBand(band)) {
    return;
  }

  final int avgWidth = band.averageWidth;
  if (avgWidth <= 0) {
    return;
  }

  int index = 0;
  while (index < band.artifacts.length) {
    final Artifact artifact = band.artifacts[index];
    if (!_shouldTryTrailingUppercaseISplit(artifact, avgWidth)) {
      index++;
      continue;
    }

    final _UppercaseTrailingISplitCandidate? candidate =
        _bestTrailingUppercaseISplit(instance, artifact);
    if (candidate == null) {
      index++;
      continue;
    }

    candidate.left.matchingCharacter = candidate.leftMatch.character;
    candidate.left.matchingScore = candidate.leftMatch.score;
    candidate.left.wasPartOfSplit = true;
    candidate.right.matchingCharacter = candidate.rightMatch.character;
    candidate.right.matchingScore = candidate.rightMatch.score;
    candidate.right.wasPartOfSplit = true;
    band.replaceOneArtifactWithMore(artifact, <Artifact>[
      candidate.left,
      candidate.right,
    ]);
    index += _splitPartCount;
  }
}

/// Returns true when a weak wide uppercase glyph may end with a trailing `I`.
///
/// This keeps the split search limited to uppercase artifacts whose width,
/// stem count, enclosure count, and low confidence all suggest a merged glyph.
bool _shouldTryTrailingUppercaseISplit(Artifact artifact, int averageWidth) {
  if (!isUppercaseLetter(artifact.matchingCharacter)) {
    return false;
  }
  if (artifact.matchingScore >
      Textify._uppercaseTrailingISplitMaxOriginalScore) {
    return false;
  }
  if (artifact.enclosures != 0) {
    return false;
  }
  if (artifact.countVerticalStems() < Textify._uppercaseMStemThreshold) {
    return false;
  }
  return artifact.rectFound.width >=
      (averageWidth * Textify._uppercaseTrailingISplitWidthRatio).round();
}

/// Finds the best cut that turns one artifact into `uppercase + I`.
///
/// Each legal split point is rescored independently, and the best candidate is
/// accepted only when the right fragment is a strong `I` and the split gains
/// enough average confidence over the original merged match.
_UppercaseTrailingISplitCandidate? _bestTrailingUppercaseISplit(
  Textify instance,
  Artifact artifact,
) {
  final int minPartWidth = Textify._uppercaseTrailingISplitMinPartWidth;
  if (artifact.cols < (minPartWidth * _splitPartCount)) {
    return null;
  }

  _UppercaseTrailingISplitCandidate? best;
  for (int cut = minPartWidth; cut <= artifact.cols - minPartWidth; cut++) {
    final Artifact left = artifact.extractSubGrid(
      rect: IntRect.fromLTWH(0, 0, cut, artifact.rows),
    );
    final Artifact right = artifact.extractSubGrid(
      rect: IntRect.fromLTWH(cut, 0, artifact.cols - cut, artifact.rows),
    );

    final List<ScoreMatch> leftScores = instance
        .getMatchingScoresOfNormalizedMatrix(left);
    final List<ScoreMatch> rightScores = instance
        .getMatchingScoresOfNormalizedMatrix(right);
    if (leftScores.isEmpty || rightScores.isEmpty) {
      continue;
    }

    final ScoreMatch leftMatch = leftScores.first;
    final ScoreMatch rightMatch = rightScores.first;
    if (!isUppercaseLetter(leftMatch.character) ||
        rightMatch.character != 'I') {
      continue;
    }

    if (rightMatch.score < Textify._uppercaseTrailingISplitMinIScore) {
      continue;
    }

    final double averageScore = (leftMatch.score + rightMatch.score) / 2;
    if ((averageScore - artifact.matchingScore) <
        Textify._uppercaseTrailingISplitMinGain) {
      continue;
    }

    if (best == null || averageScore > best.averageScore) {
      best = _UppercaseTrailingISplitCandidate(
        left: left,
        right: right,
        leftMatch: leftMatch,
        rightMatch: rightMatch,
        averageScore: averageScore,
      );
    }
  }

  return best;
}

class _UppercaseTrailingISplitCandidate {
  const _UppercaseTrailingISplitCandidate({
    required this.left,
    required this.right,
    required this.leftMatch,
    required this.rightMatch,
    required this.averageScore,
  });

  final Artifact left;
  final Artifact right;
  final ScoreMatch leftMatch;
  final ScoreMatch rightMatch;
  final double averageScore;
}

/// Repairs split uppercase `LA` when `A` sheds a narrow slash fragment.
void _repairSplitUppercaseLA(Textify instance, Band band) {
  if (!Textify._looksLikeUppercaseProseBand(band)) {
    return;
  }

  final int avgWidth = band.averageWidth;
  if (avgWidth <= 0) {
    return;
  }

  int index = 0;
  while (index < band.artifacts.length - 1) {
    final Artifact current = band.artifacts[index];
    final Artifact next = band.artifacts[index + 1];
    final List<ScoreMatch> nextScores = instance
        .getMatchingScoresOfNormalizedMatrix(next);
    if (!_shouldTryUppercaseLASplit(
      band,
      current,
      next,
      nextScores,
      avgWidth,
    )) {
      index++;
      continue;
    }

    final _UppercaseLASplitCandidate? candidate = _bestUppercaseLASplit(
      instance,
      current,
      next,
    );
    if (candidate == null) {
      index++;
      continue;
    }

    candidate.left.matchingCharacter = candidate.leftMatch.character;
    candidate.left.matchingScore = candidate.leftMatch.score;
    candidate.left.wasPartOfSplit = true;
    candidate.right.matchingCharacter = candidate.rightMatch.character;
    candidate.right.matchingScore = candidate.rightMatch.score;
    candidate.right.wasPartOfSplit = true;
    band.artifacts.removeAt(index + 1);
    band.artifacts.removeAt(index);
    band.artifacts.insertAll(index, <Artifact>[
      candidate.left,
      candidate.right,
    ]);
    band.clearStats();
    index += _splitPartCount;
  }
}

/// Returns true when adjacent uppercase artifacts resemble a broken `LA` pair.
///
/// The current artifact must look like a weak wide uppercase letter, the next
/// artifact must be a narrow fragment close by, and that fragment must still
/// score competitively as a slash-like shape.
bool _shouldTryUppercaseLASplit(
  Band band,
  Artifact current,
  Artifact next,
  List<ScoreMatch> nextScores,
  int averageWidth,
) {
  if (!isUppercaseLetter(current.matchingCharacter)) {
    return false;
  }
  if (current.matchingScore > Textify._uppercaseLASplitMaxOriginalScore) {
    return false;
  }
  if (current.enclosures != 0 || current.countVerticalStems() > 1) {
    return false;
  }
  if (current.rectFound.width <
      (averageWidth * Textify._uppercaseLASplitMinCurrentWidthRatio).round()) {
    return false;
  }

  if (next.enclosures != 0 || next.countVerticalStems() > 1) {
    return false;
  }
  if (next.rectFound.width >
      (averageWidth * Textify._uppercaseLASplitMaxFragmentWidthRatio).round()) {
    return false;
  }

  final int gap = next.rectFound.left - current.rectFound.right;
  final int maxGap = max(1, band.averageKerning ~/ 2);
  if (gap < 0 || gap > maxGap) {
    return false;
  }

  return _looksLikeSlashFragment(nextScores);
}

/// Returns true when the fragment still behaves like a slash candidate.
///
/// This accepts direct slash or backslash near-misses as well as the common
/// `X`/`x` proxy that appears when a thin diagonal fragment is matched alone.
bool _looksLikeSlashFragment(List<ScoreMatch> scores) {
  if (scores.isEmpty) {
    return false;
  }

  final double bestScore = scores.first.score;
  final double? slashScore = _scoreForCharacter(scores, '/');
  final double? backslashScore = _scoreForCharacter(scores, '\\');

  if ((slashScore != null &&
          (bestScore - slashScore) <=
              Textify._uppercaseLASplitSlashCandidateDelta) ||
      (backslashScore != null &&
          (bestScore - backslashScore) <=
              Textify._uppercaseLASplitSlashCandidateDelta)) {
    return true;
  }

  return scores.first.character == 'X' || scores.first.character == 'x';
}

/// Finds the highest-confidence `L` + `A` split for a merged uppercase pair.
///
/// The merged artifact is cut at every legal boundary and rescored. A split is
/// kept only when the left side cleanly reads as `L`, the right side keeps the
/// `A` enclosure, and the combined score improves enough over the originals.
_UppercaseLASplitCandidate? _bestUppercaseLASplit(
  Textify instance,
  Artifact current,
  Artifact next,
) {
  final Artifact merged = Artifact.fromMatrix(current);
  merged.mergeArtifact(next);

  final int minPartWidth = Textify._uppercaseLASplitMinPartWidth;
  if (merged.cols < (minPartWidth * _splitPartCount) ||
      merged.enclosures == 0) {
    return null;
  }

  final double originalAverage =
      (current.matchingScore + next.matchingScore) / 2;

  _UppercaseLASplitCandidate? best;
  for (int cut = minPartWidth; cut <= merged.cols - minPartWidth; cut++) {
    final Artifact left = merged.extractSubGrid(
      rect: IntRect.fromLTWH(0, 0, cut, merged.rows),
    );
    final Artifact right = merged.extractSubGrid(
      rect: IntRect.fromLTWH(cut, 0, merged.cols - cut, merged.rows),
    );
    if (left.enclosures != 0 || right.enclosures != 1) {
      continue;
    }

    final List<ScoreMatch> leftScores = instance
        .getMatchingScoresOfNormalizedMatrix(left);
    final List<ScoreMatch> rightScores = instance
        .getMatchingScoresOfNormalizedMatrix(right);
    if (leftScores.isEmpty || rightScores.isEmpty) {
      continue;
    }

    final ScoreMatch leftMatch = leftScores.first;
    final ScoreMatch rightMatch = rightScores.first;
    if (leftMatch.character != 'L' || rightMatch.character != 'A') {
      continue;
    }
    if (leftMatch.score < Textify._uppercaseLASplitMinLScore ||
        rightMatch.score < Textify._uppercaseLASplitMinAScore) {
      continue;
    }

    final double averageScore = (leftMatch.score + rightMatch.score) / 2;
    if ((averageScore - originalAverage) < Textify._uppercaseLASplitMinGain) {
      continue;
    }

    if (best == null || averageScore > best.averageScore) {
      best = _UppercaseLASplitCandidate(
        left: left,
        right: right,
        leftMatch: leftMatch,
        rightMatch: rightMatch,
        averageScore: averageScore,
      );
    }
  }

  return best;
}

class _UppercaseLASplitCandidate {
  const _UppercaseLASplitCandidate({
    required this.left,
    required this.right,
    required this.leftMatch,
    required this.rightMatch,
    required this.averageScore,
  });

  final Artifact left;
  final Artifact right;
  final ScoreMatch leftMatch;
  final ScoreMatch rightMatch;
  final double averageScore;
}

/// Iterates contiguous alphabetic tokens and reports their case counts.
void _forEachLetterToken(
  List<Artifact> artifacts,
  void Function(int, int, int, int) onToken,
) {
  int index = 0;
  while (index < artifacts.length) {
    while (index < artifacts.length &&
        !isLetter(artifacts[index].matchingCharacter)) {
      index++;
    }
    if (index >= artifacts.length) {
      return;
    }

    int end = index;
    int lowerCount = 0;
    int upperCount = 0;
    while (end < artifacts.length &&
        isLetter(artifacts[end].matchingCharacter)) {
      if (isLowercaseLetter(artifacts[end].matchingCharacter)) {
        lowerCount++;
      } else if (isUppercaseLetter(artifacts[end].matchingCharacter)) {
        upperCount++;
      }
      end++;
    }

    onToken(index, end, lowerCount, upperCount);
    index = end;
  }
}

/// Refines ordinary title-case tokens inside mixed-case prose bands.
///
/// This catches internal `l` vs `i` misses in words like `Version` without
/// touching mixed-case brands such as `OpenAI`, which contain additional
/// uppercase letters beyond the initial title-case prefix.
void _refineTitleCaseTokensInMixedCaseBand(Textify instance, Band band) {
  if (Textify._looksLikeUppercaseProseBand(band) ||
      Textify._looksLikeLowercaseProseBand(band)) {
    return;
  }

  final List<Artifact> artifacts = band.artifacts;
  _forEachLetterToken(artifacts, (
    int index,
    int end,
    int lowerCount,
    int upperCount,
  ) {
    final int tokenLength = end - index;
    final bool titleCaseLike =
        tokenLength >= Textify._structuredTitleCaseTokenMinLength &&
        isUppercaseLetter(artifacts[index].matchingCharacter) &&
        upperCount == 1 &&
        lowerCount == tokenLength - 1;
    if (titleCaseLike) {
      _refineStructuredTitleCaseToken(instance, artifacts, index, end);
    }
  });
}

/// Refines lowercase-like prose tokens inside mixed-content bands.
///
/// Sentence bands that include dates, punctuation, or a stray uppercase OCR
/// miss do not qualify as lowercase prose globally, but their ordinary word
/// tokens can still use lowercase-local rescues such as `l -> i` and `o -> e`.
void _refineLowercaseLikeTokens(Textify instance, Band band) {
  if (Textify._looksLikeUppercaseProseBand(band)) {
    return;
  }

  final List<Artifact> artifacts = band.artifacts;
  _forEachLetterToken(artifacts, (
    int index,
    int end,
    int lowerCount,
    int upperCount,
  ) {
    final int tokenLength = end - index;
    final bool lowercaseLike =
        tokenLength >= Textify._lowercaseTokenRefinementMinLength &&
        upperCount <= Textify._lowercaseTokenMaxUppercase &&
        lowerCount >= tokenLength - Textify._lowercaseTokenMaxUppercase;
    if (lowercaseLike) {
      _refineLowercaseLikeToken(instance, artifacts, index, end);
    }
  });
}

/// Refines local lowercase confusions inside a lowercase-like token.
void _refineLowercaseLikeToken(
  Textify instance,
  List<Artifact> artifacts,
  int start,
  int end,
) {
  for (int i = start; i < end; i++) {
    final Artifact artifact = artifacts[i];
    final List<ScoreMatch> scores = instance
        .getMatchingScoresOfNormalizedMatrix(artifact);

    if (artifact.matchingCharacter == 'l' && i > start && i < end - 1) {
      final double? iScore = _scoreForCharacter(scores, 'i');
      if (iScore != null &&
          (artifact.matchingScore - iScore) <=
              Textify._lowercaseILPromotionDelta) {
        artifact.matchingCharacter = 'i';
        artifact.matchingScore = iScore;
        continue;
      }
    }

    if (artifact.matchingCharacter != 'o' || artifact.enclosures != 1) {
      continue;
    }

    final double? eScore = _scoreForCharacter(scores, 'e');
    if (eScore == null ||
        (artifact.matchingScore - eScore) >
            Textify._lowercaseOEPromotionDelta ||
        _lowerThirdDensity(artifact) > Textify._lowercaseESparseLowerThirdMax) {
      continue;
    }

    artifact.matchingCharacter = 'e';
    artifact.matchingScore = eScore;
  }
}

/// Refines structured field labels/values using token-local case context.
void _refineStructuredFieldTokenCase(Textify instance, Band band) {
  final List<Artifact> artifacts = band.artifacts;
  final int colonIndex = artifacts.indexWhere(
    (artifact) => artifact.matchingCharacter == ':',
  );
  if (colonIndex <= 0 || colonIndex >= artifacts.length - 1) {
    return;
  }

  int labelStart = colonIndex - 1;
  while (labelStart > 0 &&
      isLetter(artifacts[labelStart - 1].matchingCharacter)) {
    labelStart--;
  }
  if ((colonIndex - labelStart) >= Textify._structuredTitleCaseTokenMinLength) {
    _refineStructuredTitleCaseToken(
      instance,
      artifacts,
      labelStart,
      colonIndex,
    );
  }

  int index = colonIndex + 1;
  while (index < artifacts.length) {
    while (index < artifacts.length &&
        !isLetter(artifacts[index].matchingCharacter)) {
      index++;
    }
    if (index >= artifacts.length) {
      return;
    }

    int end = index;
    int upperCount = 0;
    while (end < artifacts.length &&
        isLetter(artifacts[end].matchingCharacter)) {
      if (isUppercaseLetter(artifacts[end].matchingCharacter)) {
        upperCount++;
      }
      end++;
    }

    final int tokenLength = end - index;
    if (tokenLength >= Textify._structuredUppercaseTokenMinLength &&
        upperCount >= Textify._structuredUppercaseTokenMinUppercase) {
      _refineStructuredUppercaseToken(instance, artifacts, index, end);
    } else if (tokenLength >= Textify._structuredTitleCaseTokenMinLength &&
        upperCount <= 1) {
      _refineStructuredTitleCaseToken(instance, artifacts, index, end);
    }

    index = end;
  }
}

/// Promotes stronger uppercase candidates inside mixed alphanumeric code tokens.
void _refineCodeLikeTokenCharacters(Textify instance, Band band) {
  final List<Artifact> artifacts = band.artifacts;
  int index = 0;
  while (index < artifacts.length) {
    while (index < artifacts.length &&
        !_isCodeLikeTokenCharacter(artifacts[index].matchingCharacter)) {
      index++;
    }
    if (index >= artifacts.length) {
      return;
    }

    int end = index;
    int letterCount = 0;
    int digitCount = 0;
    while (end < artifacts.length &&
        _isCodeLikeTokenCharacter(artifacts[end].matchingCharacter)) {
      final String character = artifacts[end].matchingCharacter;
      if (isLetter(character)) {
        letterCount++;
      } else if (isDigit(character)) {
        digitCount++;
      }
      end++;
    }

    final int tokenLength = end - index;
    if (tokenLength >= Textify._codeTokenRefinementMinLength &&
        letterCount >= Textify._codeTokenRefinementMinLetters &&
        digitCount >= Textify._codeTokenRefinementMinDigits) {
      _refineCodeLikeToken(instance, artifacts, index, end);
    }

    index = end;
  }
}

bool _isCodeLikeTokenCharacter(String character) {
  return isLetter(character) || isDigit(character);
}

/// Refines interior letter runs in a mixed alphanumeric code token.
///
/// This only touches letter runs that are bounded by digits on both sides,
/// which keeps corrections scoped to embedded code suffixes such as `34EF56`
/// and avoids rewriting leading alpha prefixes like `LSIAK28I5`.
void _refineCodeLikeToken(
  Textify instance,
  List<Artifact> artifacts,
  int start,
  int end,
) {
  int index = start;
  while (index < end) {
    while (index < end && !isLetter(artifacts[index].matchingCharacter)) {
      index++;
    }
    if (index >= end) {
      return;
    }

    int runEnd = index;
    while (runEnd < end && isLetter(artifacts[runEnd].matchingCharacter)) {
      runEnd++;
    }

    final bool digitBefore =
        index > start && isDigit(artifacts[index - 1].matchingCharacter);
    final bool digitAfter =
        runEnd < end && isDigit(artifacts[runEnd].matchingCharacter);
    if (digitBefore && digitAfter) {
      for (int i = index; i < runEnd; i++) {
        final Artifact artifact = artifacts[i];
        final List<ScoreMatch> scores = instance
            .getMatchingScoresOfNormalizedMatrix(artifact);
        final ScoreMatch? candidate = _bestCodeLikeUppercaseCandidate(
          artifact,
          scores,
        );
        if (candidate == null) {
          continue;
        }

        artifact.matchingCharacter = candidate.character;
        artifact.matchingScore = candidate.score;
      }
    }

    index = runEnd;
  }
}

/// Picks the strongest uppercase code candidate when structure improves.
///
/// For already-uppercase glyphs, candidates must strictly reduce structural
/// mismatch. For lowercase leftovers inside code runs, the same-letter
/// uppercase form is allowed, or any uppercase candidate with a better
/// enclosure/stem match.
ScoreMatch? _bestCodeLikeUppercaseCandidate(
  Artifact artifact,
  List<ScoreMatch> scores,
) {
  if (scores.isEmpty) {
    return null;
  }

  final int currentMismatch = _candidateStructuralMismatch(
    artifact,
    artifact.matchingCharacter,
  );
  final bool currentUppercase = isUppercaseLetter(artifact.matchingCharacter);
  final String currentUpper = artifact.matchingCharacter.toUpperCase();

  ScoreMatch? best;
  int bestMismatch = _structuralMismatchSentinel;
  for (final ScoreMatch candidate in scores) {
    if ((artifact.matchingScore - candidate.score) >
        Textify._codeTokenStructurePromotionDelta) {
      break;
    }
    if (!isUppercaseLetter(candidate.character)) {
      continue;
    }

    final int mismatch = _candidateStructuralMismatch(
      artifact,
      candidate.character,
    );
    final bool sameLetterUppercase = candidate.character == currentUpper;
    final bool eligible = currentUppercase
        ? mismatch < currentMismatch
        : sameLetterUppercase || mismatch < currentMismatch;
    if (!eligible) {
      continue;
    }

    if (best == null ||
        mismatch < bestMismatch ||
        (mismatch == bestMismatch &&
            candidate.score > best.score + Textify._scoreEqualityTolerance)) {
      best = candidate;
      bestMismatch = mismatch;
    }
  }

  return best;
}

/// Promotes a likely title-case token using case-compatible candidates.
void _refineStructuredTitleCaseToken(
  Textify instance,
  List<Artifact> artifacts,
  int start,
  int end,
) {
  if ((end - start) < Textify._structuredTitleCaseTokenMinLength) {
    return;
  }

  final Artifact first = artifacts[start];
  if (isLetter(first.matchingCharacter) &&
      !isUppercaseLetter(first.matchingCharacter)) {
    final List<ScoreMatch> scores = instance
        .getMatchingScoresOfNormalizedMatrix(first);
    final ScoreMatch? uppercaseCandidate = _bestCaseCandidate(
      first,
      scores,
      preferUppercase: true,
      allowedDelta: Textify._structuredTokenCasePromotionDelta,
    );
    if (uppercaseCandidate != null) {
      first.matchingCharacter = uppercaseCandidate.character;
      first.matchingScore = uppercaseCandidate.score;
    }
  }

  for (int i = start + 1; i < end; i++) {
    final Artifact artifact = artifacts[i];
    if (artifact.matchingCharacter != 'l') {
      continue;
    }

    final List<ScoreMatch> scores = instance
        .getMatchingScoresOfNormalizedMatrix(artifact);
    final double? iScore = _scoreForCharacter(scores, 'i');
    if (iScore == null ||
        (artifact.matchingScore - iScore) >
            Textify._lowercaseILPromotionDelta) {
      continue;
    }

    artifact.matchingCharacter = 'i';
    artifact.matchingScore = iScore;
  }
}

/// Promotes a likely all-uppercase structured value token.
void _refineStructuredUppercaseToken(
  Textify instance,
  List<Artifact> artifacts,
  int start,
  int end,
) {
  for (int i = start; i < end; i++) {
    final Artifact artifact = artifacts[i];
    if (!isLetter(artifact.matchingCharacter)) {
      continue;
    }

    final List<ScoreMatch> scores = instance
        .getMatchingScoresOfNormalizedMatrix(artifact);

    if (artifact.matchingCharacter == 'F') {
      final double? eScore = _scoreForCharacter(scores, 'E');
      if (eScore != null &&
          (artifact.matchingScore - eScore) <= Textify._uppercaseEFSwapDelta &&
          _lowerThirdDensity(artifact) >
              Textify._uppercaseFSparseLowerThirdMax) {
        artifact.matchingCharacter = 'E';
        artifact.matchingScore = eScore;
        continue;
      }
    }

    if (isUppercaseLetter(artifact.matchingCharacter)) {
      continue;
    }

    final ScoreMatch? uppercaseCandidate = _bestCaseCandidate(
      artifact,
      scores,
      preferUppercase: true,
      allowedDelta: Textify._structuredTokenCasePromotionDelta,
    );
    if (uppercaseCandidate == null) {
      continue;
    }

    artifact.matchingCharacter = uppercaseCandidate.character;
    artifact.matchingScore = uppercaseCandidate.score;
  }
}

/// Returns the best case-compatible candidate within [allowedDelta].
ScoreMatch? _bestCaseCandidate(
  Artifact artifact,
  List<ScoreMatch> scores, {
  required bool preferUppercase,
  required double allowedDelta,
}) {
  if (scores.isEmpty) {
    return null;
  }

  ScoreMatch? best;
  int bestMismatch = _structuralMismatchSentinel;
  for (final ScoreMatch candidate in scores) {
    if ((artifact.matchingScore - candidate.score) > allowedDelta) {
      break;
    }

    final bool caseMatches = preferUppercase
        ? isUppercaseLetter(candidate.character)
        : isLowercaseLetter(candidate.character);
    if (!caseMatches) {
      continue;
    }

    final int mismatch = _candidateStructuralMismatch(
      artifact,
      candidate.character,
    );
    if (best == null ||
        mismatch < bestMismatch ||
        (mismatch == bestMismatch &&
            candidate.score > best.score + Textify._scoreEqualityTolerance)) {
      best = candidate;
      bestMismatch = mismatch;
    }
  }

  return best;
}

/// Counts enclosure/vertical-line mismatches for [candidate].
int _candidateStructuralMismatch(Artifact artifact, String candidate) {
  final CharacterDefinition? definition = Textify.characterDefinitions
      .getDefinition(candidate);
  if (definition == null) {
    return _structuralMismatchSentinel;
  }

  int mismatch = 0;
  if (artifact.enclosures != definition.enclosures) {
    mismatch++;
  }
  if (artifact.verticalLineLeft != definition.lineLeft) {
    mismatch++;
  }
  if (artifact.verticalLineRight != definition.lineRight) {
    mismatch++;
  }
  return mismatch;
}

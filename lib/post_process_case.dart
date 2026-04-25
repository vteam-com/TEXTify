/// Case normalization passes for OCR post-processing.
///
/// Handles I/L ambiguity resolution, word-level case coherence,
/// line-level case normalization, and name-like title-case formatting.
library;

import 'package:textify/models/english_words.dart';
import 'package:textify/post_process_helpers.dart';

const int _minLettersForCaseNormalization = 3;
const double _dominantCaseRatio = 0.9;
const int _uppercaseICodeUnit = 73;
const int _lowercaseLCodeUnit = 108;
const int _minWordLengthForILAmbiguity = 2;
const int _minWordLengthForCaseCoherence = 3;
const int _nameLikeLineMinTokens = 2;
const int _nameLikeLineMaxTokens = 4;
const int _titleCasePreserveLowerTokenMaxLength = 2;

/// Resolves I/l ambiguity based on word-level case context.
///
/// Uppercase 'I' and lowercase 'l' are nearly identical vertical strokes
/// that OCR frequently confuses. When the surrounding letters in a word
/// establish a dominant case, the ambiguous glyph is matched to that case.
///
/// Positional exceptions:
///  - An 'I' at the START of a word is never changed: it could be a
///    capitalized word like "In" or "Is".
///  - An 'I' preceded by another uppercase letter is never changed: it
///    is likely part of an acronym suffix like "OpenAI" or "GPT-4I".
String resolveILAmbiguity(String line) {
  return line.replaceAllMapped(RegExp(r'[A-Za-z]+'), (match) {
    final String word = match.group(0)!;
    if (word.length < _minWordLengthForILAmbiguity) {
      return word;
    }

    // Count unambiguous case characters (exclude I and l)
    int upper = 0;
    int lower = 0;
    bool hasI = false;
    bool hasLowerL = false;
    for (int i = 0; i < word.length; i++) {
      final int code = word.codeUnitAt(i);
      if (code == _uppercaseICodeUnit) {
        hasI = true;
      } else if (code == _lowercaseLCodeUnit) {
        hasLowerL = true;
      } else if (isUpper(code)) {
        upper++;
      } else if (isLower(code)) {
        lower++;
      }
    }

    if (!hasI && !hasLowerL) {
      return word;
    }

    if (upper > lower && hasLowerL) {
      return word.replaceAll('l', 'I');
    }

    if (lower > upper && hasI) {
      // Only convert I→l when the I is clearly in a lowercase context:
      // skip I at position 0 (could be a capitalized word like "In")
      // and skip I preceded by an uppercase letter (acronym like "OpenAI").
      final StringBuffer sb = StringBuffer();
      for (int i = 0; i < word.length; i++) {
        final int code = word.codeUnitAt(i);
        if (code == _uppercaseICodeUnit) {
          final bool atStart = i == 0;
          final bool afterUpper = i > 0 && isUpper(word.codeUnitAt(i - 1));
          if (atStart || afterUpper) {
            sb.writeCharCode(code); // keep as I
          } else {
            sb.write('l'); // convert to l
          }
        } else {
          sb.writeCharCode(code);
        }
      }
      return sb.toString();
    }

    return word;
  });
}

/// Normalizes stray case-flipped characters within case-consistent words.
///
/// In words of 3+ letters where all but one character share the same case,
/// the outlier is corrected to match. This handles common OCR errors where
/// a single character is recognized in the wrong case.
String normalizeWordCaseCoherence(String line) {
  return line.replaceAllMapped(RegExp(r'[A-Za-z]+'), (match) {
    final String word = match.group(0)!;
    if (word.length < _minWordLengthForCaseCoherence) {
      return word;
    }

    int upper = 0;
    int lower = 0;
    for (int i = 0; i < word.length; i++) {
      final int code = word.codeUnitAt(i);
      if (isUpper(code)) {
        upper++;
      } else if (isLower(code)) {
        lower++;
      }
    }

    final int total = upper + lower;
    if (total < _minWordLengthForCaseCoherence) {
      return word;
    }

    // If one case is strongly dominant, normalize the word
    if (total >= _minWordLengthForCaseCoherence) {
      if (upper >= total - 1 && upper > lower) {
        return word.toUpperCase();
      }
      if (lower >= total - 1 && lower > upper) {
        // Preserve Title Case
        if (isUpper(word.codeUnitAt(0))) {
          return sentenceCase(word.toLowerCase());
        }
        return word.toLowerCase();
      }
    }

    return word;
  });
}

/// Normalizes dominant line casing while preserving mixed-case lines.
String normalizeLineCase(String line) {
  int letters = 0;
  int upper = 0;
  int lower = 0;
  int? firstLetterCode;

  for (int i = 0; i < line.length; i++) {
    final int code = line.codeUnitAt(i);
    if (isUpper(code)) {
      letters++;
      upper++;
      firstLetterCode ??= code;
    } else if (isLower(code)) {
      letters++;
      lower++;
      firstLetterCode ??= code;
    }
  }

  if (letters < _minLettersForCaseNormalization) {
    return line;
  }

  final double upperRatio = upper / letters;
  final double lowerRatio = lower / letters;

  if (upperRatio >= _dominantCaseRatio) {
    return line.toUpperCase();
  }
  if (lowerRatio >= _dominantCaseRatio && firstLetterCode != null) {
    return sentenceCase(line.toLowerCase());
  }

  return line;
}

/// Applies title-case to all words in name-like lines.
///
/// This pass is intentionally narrow: only alphabetic lines with 2-4 tokens
/// where at least one token already looks title-cased and at most one token is
/// fully lowercase. This avoids changing normal sentence lines.
String normalizeNameLikeLineTitleCase(String line) {
  if (line.isEmpty || RegExp(r'[^A-Za-z\s]').hasMatch(line)) {
    return line;
  }

  final List<String> tokens = line
      .split(RegExp(r'\s+'))
      .where((String token) => token.isNotEmpty)
      .toList();
  if (tokens.length < _nameLikeLineMinTokens ||
      tokens.length > _nameLikeLineMaxTokens) {
    return line;
  }

  // If it's a 2-word line starting with a TitleCase word followed by a common lowercase word,
  // it's likely a sentence rather than a name.
  if (tokens.length == _nameLikeLineMinTokens &&
      isTitleCaseWord(tokens[0]) &&
      tokens[1] == tokens[1].toLowerCase() &&
      englishWords.contains(tokens[1])) {
    return line;
  }

  int titleCaseTokens = 0;
  int lowercaseTokens = 0;
  for (final String token in tokens) {
    if (!isAlphaWord(token)) {
      return line;
    }

    if (isTitleCaseWord(token)) {
      titleCaseTokens++;
      continue;
    }

    if (token == token.toLowerCase()) {
      lowercaseTokens++;
      continue;
    }

    return line;
  }

  if (titleCaseTokens == 0 || lowercaseTokens > 1) {
    return line;
  }

  final List<String> normalized = <String>[];
  for (int i = 0; i < tokens.length; i++) {
    final String token = tokens[i];
    if (i > 0 &&
        token == token.toLowerCase() &&
        token.length <= _titleCasePreserveLowerTokenMaxLength) {
      normalized.add(token);
      continue;
    }
    normalized.add(toTitleCaseWord(token));
  }

  return normalized.join(' ');
}

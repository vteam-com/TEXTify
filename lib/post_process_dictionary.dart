/// Dictionary-based near-miss correction for OCR post-processing.
///
/// Corrects single-character OCR confusions in non-dictionary words
/// using edit-distance matching.
library;

import 'package:textify/correction.dart';
import 'package:textify/models/english_words.dart';
import 'package:textify/post_process_helpers.dart';

const int _nearMissMinTokenLength = 3;
const int _uppercaseSentenceMinTokens = 5;
const int _uppercaseSentenceMaxMisses = 2;
const int _uppercaseNearMissMinTokenLength = 4;
const int _uppercaseNearMissDistance = 2;
const int _uppercaseInsertionDeletionDistance = 1;

/// Finds a dictionary suggestion for uppercase prose tokens missing one letter.
///
/// This only accepts candidates that differ by a single insertion/deletion so
/// lines like `THE QUCK BROWN...` can recover `QUICK` without broadening the
/// normal near-miss policy for codes and abbreviations.
String? _findClosestUppercaseLengthFlexibleSuggestion(String token) {
  final String lower = token.toLowerCase();
  String? bestSuggestion;

  for (final String dictWord in englishWords) {
    if (dictWord.length != lower.length + 1) {
      continue;
    }

    if (levenshteinDistance(lower, dictWord) !=
        _uppercaseInsertionDeletionDistance) {
      continue;
    }

    if (!_isSingleInsertionDeletionNearMatch(lower, dictWord)) {
      continue;
    }

    if (bestSuggestion == null || dictWord.compareTo(bestSuggestion) < 0) {
      bestSuggestion = dictWord;
    }
  }

  return bestSuggestion;
}

/// Returns true when two strings differ by exactly one inserted character.
///
/// The caller already constrains edit distance to 1, and this helper narrows
/// that to the specific insertion/deletion shape used by uppercase prose repair.
bool _isSingleInsertionDeletionNearMatch(String source, String candidate) {
  if ((source.length - candidate.length).abs() != 1) {
    return false;
  }

  final String shorter = source.length < candidate.length ? source : candidate;
  final String longer = source.length < candidate.length ? candidate : source;

  int shorterIndex = 0;
  int longerIndex = 0;
  bool skippedExtraCharacter = false;

  while (shorterIndex < shorter.length && longerIndex < longer.length) {
    if (shorter[shorterIndex] == longer[longerIndex]) {
      shorterIndex++;
      longerIndex++;
      continue;
    }

    if (skippedExtraCharacter) {
      return false;
    }

    skippedExtraCharacter = true;
    longerIndex++;
  }

  if (longerIndex < longer.length) {
    if (skippedExtraCharacter) {
      return false;
    }
    skippedExtraCharacter = true;
    longerIndex++;
  }

  return skippedExtraCharacter &&
      shorterIndex == shorter.length &&
      longerIndex == longer.length;
}

/// Detects all-uppercase prose lines where near-miss dictionary repair is safe.
///
/// The line must look sentence-like rather than code-like, and almost all
/// alphabetic tokens must already be dictionary words so the remaining misses
/// are likely OCR confusions instead of identifiers or abbreviations.
bool _looksLikeUppercaseProseLine(String line) {
  if (hasCodeLikeToken(line)) {
    return false;
  }

  final List<String> tokens = RegExp(
    r'[A-Za-z]+',
  ).allMatches(line).map((match) => match.group(0)!).toList();
  if (tokens.length < _uppercaseSentenceMinTokens) {
    return false;
  }

  int dictionaryTokens = 0;
  for (final String token in tokens) {
    if (token != token.toUpperCase()) {
      return false;
    }
    if (englishWords.contains(token.toLowerCase())) {
      dictionaryTokens++;
    }
  }

  return dictionaryTokens >= (tokens.length - _uppercaseSentenceMaxMisses);
}

/// Corrects near-miss dictionary words with strict edit-distance limits.
String correctNearMissDictionaryWords(String line) {
  if (line.isEmpty) {
    return line;
  }

  final bool allowUppercaseProseCorrection = _looksLikeUppercaseProseLine(line);

  return line.replaceAllMapped(RegExp(r'[A-Za-z]+'), (Match match) {
    final String token = match.group(0)!;
    final bool tokenIsUppercase = token == token.toUpperCase();
    if (token.length < _nearMissMinTokenLength) {
      return token;
    }

    // Protect mixed-case words (e.g., 'OpenAI') and acronyms (e.g., 'GPT')
    // from being "corrected" to lowercase dictionary words.
    if (isMixedCase(token)) {
      return token;
    }
    if (isAcronym(token) &&
        !(allowUppercaseProseCorrection && tokenIsUppercase)) {
      return token;
    }

    final String lower = token.toLowerCase();
    if (englishWords.contains(lower)) {
      return token;
    }

    String suggestion = findClosestMatchingWordInDictionary(token);
    bool allowCorrection = false;

    if (suggestion.isNotEmpty && suggestion.length == token.length) {
      final int distance = levenshteinDistance(lower, suggestion.toLowerCase());

      int diffCount = 0;
      int confusionDiffCount = 0;
      bool validSameLengthSuggestion = true;
      for (int i = 0; i < token.length; i++) {
        if (token[i].toLowerCase() != suggestion[i].toLowerCase()) {
          diffCount++;
          if (!isOcrConfusionPair(token[i], suggestion[i])) {
            validSameLengthSuggestion = false;
            break;
          }
          confusionDiffCount++;
        }
      }

      if (validSameLengthSuggestion) {
        final bool allowSingleConfusionCorrection =
            distance == 1 && diffCount == 1 && confusionDiffCount == 1;
        final bool allowUppercaseDoubleConfusionCorrection =
            allowUppercaseProseCorrection &&
            tokenIsUppercase &&
            token.length >= _uppercaseNearMissMinTokenLength &&
            distance == _uppercaseNearMissDistance &&
            diffCount == _uppercaseNearMissDistance &&
            confusionDiffCount == _uppercaseNearMissDistance;

        allowCorrection =
            allowSingleConfusionCorrection ||
            allowUppercaseDoubleConfusionCorrection;
      }
    }

    if (!allowCorrection &&
        allowUppercaseProseCorrection &&
        tokenIsUppercase &&
        token.length >= _uppercaseNearMissMinTokenLength) {
      final String? flexibleSuggestion =
          _findClosestUppercaseLengthFlexibleSuggestion(token);
      if (flexibleSuggestion != null) {
        suggestion = flexibleSuggestion;
        allowCorrection = true;
      }
    }

    if (!allowCorrection) {
      return token;
    }

    if (isTitleCaseWord(token)) {
      return toTitleCaseWord(suggestion);
    }
    if (token == token.toLowerCase()) {
      return suggestion.toLowerCase();
    }
    if (tokenIsUppercase) {
      return suggestion.toUpperCase();
    }
    return suggestion;
  });
}

const int _splitMinHalfLength = 3;
const int _splitMinTotalParts = 2;

/// Splits concatenated words that are not in the dictionary.
///
/// When space detection misses a word boundary (e.g. "foxjumps"), the
/// resulting token won't be a valid dictionary word. This pass tries every
/// split point and accepts the split when exactly one partition produces
/// two valid dictionary words, avoiding ambiguous results.
String splitConcatenatedDictionaryWords(String line) {
  return line.replaceAllMapped(RegExp(r'[A-Za-z]+'), (Match match) {
    final String token = match.group(0)!;
    if (token.length < _splitMinHalfLength * _splitMinTotalParts) {
      return token;
    }

    final String lower = token.toLowerCase();
    if (englishWords.contains(lower)) {
      return token;
    }

    String? bestLeft;
    String? bestRight;
    int splitCount = 0;

    for (
      int i = _splitMinHalfLength;
      i <= lower.length - _splitMinHalfLength;
      i++
    ) {
      final String left = lower.substring(0, i);
      final String right = lower.substring(i);
      if (englishWords.contains(left) && englishWords.contains(right)) {
        bestLeft = token.substring(0, i);
        bestRight = token.substring(i);
        splitCount++;
        if (splitCount > 1) {
          return token; // ambiguous — don't split
        }
      }
    }

    if (splitCount == 1) {
      return '$bestLeft $bestRight';
    }
    return token;
  });
}

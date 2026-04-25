/// Dictionary-based near-miss correction for OCR post-processing.
///
/// Corrects single-character OCR confusions in non-dictionary words
/// using edit-distance matching.
library;

import 'package:textify/correction.dart';
import 'package:textify/models/english_words.dart';
import 'package:textify/post_process_helpers.dart';

const int _nearMissMinTokenLength = 3;

/// Corrects near-miss dictionary words with strict edit-distance limits.
String correctNearMissDictionaryWords(String line) {
  if (line.isEmpty) {
    return line;
  }

  return line.replaceAllMapped(RegExp(r'[A-Za-z]+'), (Match match) {
    final String token = match.group(0)!;
    if (token.length < _nearMissMinTokenLength) {
      return token;
    }

    // Protect mixed-case words (e.g., 'OpenAI') and acronyms (e.g., 'GPT')
    // from being "corrected" to lowercase dictionary words.
    if (isAcronym(token) || isMixedCase(token)) {
      return token;
    }

    final String lower = token.toLowerCase();
    if (englishWords.contains(lower)) {
      return token;
    }

    final String suggestion = findClosestMatchingWordInDictionary(token);
    if (suggestion.isEmpty) {
      return token;
    }

    final int distance = levenshteinDistance(lower, suggestion.toLowerCase());

    // STRICT POLICY: Only allow corrections of distance 1 and matching length.
    if (distance != 1 || suggestion.length != token.length) {
      return token;
    }

    // Determine which character is being changed.
    int diffIndex = -1;
    for (int i = 0; i < token.length; i++) {
      if (token[i].toLowerCase() != suggestion[i].toLowerCase()) {
        diffIndex = i;
        break;
      }
    }

    if (diffIndex != -1) {
      final String from = token[diffIndex];
      final String to = suggestion[diffIndex];

      // Only allow corrections where the changed character is a known
      // OCR confusion (l/I, O/0, etc.). This prevents morphological
      // form changes like "Released" → "Releases" (d→s).
      if (!isOcrConfusionPair(from, to)) {
        return token;
      }
    }

    if (isTitleCaseWord(token)) {
      return toTitleCaseWord(suggestion);
    }
    if (token == token.toLowerCase()) {
      return suggestion.toLowerCase();
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

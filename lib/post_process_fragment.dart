/// Fragment repair passes for OCR post-processing.
///
/// Handles fragmented word reconstruction, fragment merging,
/// and split-character recovery.
library;

import 'package:textify/constants.dart';
import 'package:textify/correction.dart';
import 'package:textify/models/english_words.dart';
import 'package:textify/post_process_helpers.dart';

const int _fragmentPairMinimumTokenCount = 2;
const int _fragmentPairShortWordLength = 3;
const int _fragmentPairLeftLengthWhenRightSingle = 6;

/// Repairs fragmented words and common letter confusions in noisy lines.
String normalizeFragmentedLine(String line, {bool applyDictionary = true}) {
  if (!_looksFragmented(line)) {
    return line;
  }

  String value = line;
  // 1. Acronym context: 'l' (lowercase L) follows uppercase and isn't followed by lowercase
  // This catches 'AlB' -> 'AIB' and 'OpenAl' -> 'OpenAI'
  value = value.replaceAllMapped(
    RegExp(r'(?<=[A-Z])l(?![a-z])'),
    (_) => OcrTokens.upperI,
  );

  // 2. Common 2-letter confusion: 'ln' -> 'In'
  value = value.replaceAllMapped(RegExp(r'\bln\b'), (_) => 'In');
  value = value.replaceAllMapped(
    RegExp(r'(?<=[a-z])I(?=[a-z])'),
    (_) => OcrTokens.lowerL,
  );
  // 3. Multi-character fragmentation: 'c o d e' -> 'code'
  // This helps reconstruct spaced out words in a single pass.
  // When applyDictionary is true, avoids merging across word boundaries
  // (e.g. 'w i d g e t A' stays 'widget A' instead of becoming 'widgetA').
  value = value.replaceAllMapped(
    RegExp(r'(?<![A-Za-z])([A-Za-z])(?:\s+([A-Za-z]))+(?![A-Za-z])'),
    (Match match) {
      final String fullMatch = match.group(0)!;
      final String merged = fullMatch.replaceAll(RegExp(r'\s+'), '');
      if (applyDictionary) {
        if (englishWords.contains(merged.toLowerCase())) {
          return merged;
        }
        final String? split = _trySplitMergedCharacters(merged);
        if (split != null) {
          return split;
        }
      }
      return merged;
    },
  );

  if (applyDictionary) {
    value = _mergeLikelyWordFragments(value);
  }

  return value;
}

/// Analyzes a line to determine if it is likely fragmented OCR output.
///
/// A line is considered fragmented if it contains a high proportion of
/// very short (1-2 character) alphabetic tokens, which often indicates
/// that the OCR engine incorrectly split words due to wide kerning or
/// artifacts.
bool _looksFragmented(String line) {
  final List<String> tokens = line
      .split(RegExp(r'\s+'))
      .where((String token) => token.isNotEmpty)
      .toList();
  if (tokens.length < _fragmentPairMinimumTokenCount) {
    return false;
  }

  int shortAlpha = 0;
  for (final String token in tokens) {
    if (RegExp(r'^[A-Za-z]{1,2}$').hasMatch(token)) {
      shortAlpha++;
    }
  }
  return shortAlpha >= 1;
}

/// Merges adjacent tiny alphabetic tokens when they likely belong to one word.
String _mergeLikelyWordFragments(String line) {
  final List<String> tokens = line.split(' ');
  if (tokens.length < _fragmentPairMinimumTokenCount) {
    return line;
  }

  int i = 0;
  while (i < tokens.length - 1) {
    final String left = tokens[i];
    final String right = tokens[i + 1];
    final bool leftValid = englishWords.contains(left.toLowerCase());
    final bool rightValid = englishWords.contains(right.toLowerCase());

    // NEVER merge two already-valid words into a longer string
    // unless the result is also a dictionary word.
    if (leftValid && rightValid) {
      final String merged = left + right;
      if (englishWords.contains(merged.toLowerCase())) {
        tokens[i] = merged;
        tokens.removeAt(i + 1);
        continue;
      }
      i++;
      continue;
    }

    final bool likelyFragmentPair =
        (left.length <= _fragmentPairShortWordLength &&
            right.length <= _fragmentPairShortWordLength) ||
        (right.length == 1 &&
            left.length <= _fragmentPairLeftLengthWhenRightSingle);
    if (!likelyFragmentPair) {
      i++;
      continue;
    }

    // Never consume a valid dictionary word (≥2 chars) into a fragment merge.
    // E.g. "GPT" + "In" should stay separate because "In" is a real word.
    if (rightValid && right.length >= minAcronymTokenLength) {
      i++;
      continue;
    }

    // If the left token is already a valid dictionary word, don't merge
    // a single trailing character unless the merged result is also in
    // the dictionary. This protects labels like "Widget A" from being
    // incorrectly merged into "WidgetA" and then corrected to "Widgets".
    if (leftValid && right.length == 1) {
      final String candidateMerge = (left + right).toLowerCase();
      if (!englishWords.contains(candidateMerge)) {
        i++;
        continue;
      }
    }

    String merged = left + right;
    // Apply structural fixes to the merged result (e.g. OpenAl -> OpenAI)
    merged = merged.replaceAllMapped(
      RegExp(r'(?<=[A-Z])l(?![a-z])'),
      (_) => OcrTokens.upperI,
    );

    // If the merged result is a valid acronym or mixed-case word,
    // we accept it and merge immediately.
    if (isAcronym(merged) || isMixedCase(merged)) {
      tokens[i] = merged;
      tokens.removeAt(i + 1);
      continue;
    }

    final String lowerMerged = merged.toLowerCase();
    // Protect numbers from being matched against the dictionary.
    if (RegExp(r'\d').hasMatch(merged)) {
      i++;
      continue;
    }

    if (englishWords.contains(lowerMerged)) {
      tokens[i] = merged;
      tokens.removeAt(i + 1);
      continue;
    }

    final String suggestion = findClosestMatchingWordInDictionary(merged);
    final int distance = levenshteinDistance(
      lowerMerged,
      suggestion.toLowerCase(),
    );
    // STRICT POLICY: Only merge if the result matches a dictionary word
    // of the EXACT same length with distance 1.
    if (distance == 1 && suggestion.length == merged.length) {
      tokens[i] = isTitleCaseWord(merged)
          ? toTitleCaseWord(suggestion)
          : suggestion;
      tokens.removeAt(i + 1);
      continue;
    }

    i++;
  }

  return tokens.join(' ');
}

/// Attempts to split a merged sequence of single characters into valid words.
///
/// When fragmented character merging produces a non-dictionary string (e.g.,
/// 'widgetA' from 'w i d g e t A'), this function finds valid word boundaries
/// using a greedy longest-match strategy. A single trailing character is kept
/// as a separate token to preserve standalone letters like 'A' in 'Widget A'.
///
/// Returns the split string with spaces between words, or null if no valid
/// split can be found.
String? _trySplitMergedCharacters(String merged) {
  final String lower = merged.toLowerCase();
  final List<String> words = <String>[];
  int start = 0;

  while (start < lower.length) {
    int bestEnd = -1;
    for (int end = lower.length; end > start; end--) {
      if (englishWords.contains(lower.substring(start, end))) {
        bestEnd = end;
        break;
      }
    }

    if (bestEnd != -1) {
      words.add(merged.substring(start, bestEnd));
      start = bestEnd;
    } else if (lower.length - start == 1) {
      // Single remaining character — preserve as a separate token.
      words.add(merged.substring(start));
      start++;
    } else {
      // Multi-character remainder that isn't a dictionary word — give up.
      return null;
    }
  }

  if (words.length <= 1) {
    return null;
  }

  return words.join(' ');
}

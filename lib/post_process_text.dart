/// Text-level normalization passes for OCR post-processing.
///
/// Handles punctuation spacing, multi-character letter confusion
/// resolution, and other text-wide normalization.
library;

import 'package:textify/models/english_words.dart';
import 'package:textify/post_process_helpers.dart';

/// Normalizes punctuation spacing errors common in OCR.
String normalizePunctuationSpacing(String text) {
  // Fixes "word . next" -> "word. next"
  String result = text.replaceAllMapped(RegExp(r'\s+([.,!?;:])'), (match) {
    return match.group(regexGroupFirst)!;
  });

  // Fixes "word.next" -> "word. next" but not "www.AMAZON" (domain-like).
  // Skip inserting a space when the punctuation is a dot preceded by a
  // letter AND followed by a letter (domain, URL, or abbreviation pattern).
  // Numbered lists like "1.Hello" still get a space since the dot follows a digit.
  result = result.replaceAllMapped(RegExp(r'([.,!?;:])([A-Za-z])'), (match) {
    final String punct = match.group(regexGroupFirst)!;
    final String letter = match.group(regexGroupSecond)!;
    if (punct == '.' && match.start > 0) {
      final int prevCode = result.codeUnitAt(match.start - 1);
      if (isLetter(prevCode)) {
        return '$punct$letter';
      }
    }
    return '$punct $letter';
  });

  return result;
}

/// Normalizes common multi-character letter confusions within non-dictionary words.
///
/// OCR frequently confuses glyph sequences that look similar at low resolution:
/// 'rn' → 'm', 'cl' → 'd', 'vv' → 'w', 'III' → 'm'.
/// Only applies substitutions when the original token is NOT a valid dictionary
/// word and the replacement IS, preventing damage to correct text.
String normalizeLetterConfusions(String text) {
  const List<MapEntry<String, String>> confusions = [
    MapEntry('rn', 'm'),
    MapEntry('cl', 'd'),
    MapEntry('vv', 'w'),
    MapEntry('III', 'm'),
  ];

  return text.replaceAllMapped(RegExp(r'[A-Za-z]+'), (Match match) {
    final String token = match.group(0)!;
    final String lower = token.toLowerCase();

    // If the word is already valid, don't touch it.
    if (englishWords.contains(lower)) {
      return token;
    }

    // Try each confusion substitution and accept the first that yields
    // a valid dictionary word.
    for (final MapEntry<String, String> entry in confusions) {
      if (lower.contains(entry.key)) {
        final String candidate = lower.replaceAll(entry.key, entry.value);
        if (englishWords.contains(candidate)) {
          // Preserve original casing structure.
          if (token == token.toUpperCase()) {
            return candidate.toUpperCase();
          }
          if (isTitleCaseWord(token)) {
            return toTitleCaseWord(candidate);
          }
          return candidate;
        }
      }
    }

    return token;
  });
}

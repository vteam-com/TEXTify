/// Bracket-to-letter noise normalization for OCR post-processing.
///
/// Replaces bracket/pipe characters with visually similar uppercase
/// letters in uppercase-dominant lines.
library;

import 'package:textify/post_process_helpers.dart';

const double _bracketNoiseMinLetterRatio = 0.7;
const double _bracketNoiseMinUpperRatio = 0.8;

/// Glyph-to-uppercase-letter map for punctuation characters whose shapes
/// closely resemble specific letters.
const Map<String, String> glyphToUpperLetter = {
  '[': 'L', // vertical + bottom horizontal stroke
  ']': 'J', // vertical + bottom hook
  '|': 'I', // vertical stroke
};

/// Replaces bracket/pipe characters with visually similar uppercase letters
/// in tokens that contain them, within lines that are predominantly uppercase.
///
/// OCR engines can misrecognize letters as bracket characters when glyph
/// shapes are similar (e.g., Arial "L" → "[" due to the shared vertical-
/// plus-horizontal stroke structure). This pass recovers the intended
/// letter when the surrounding context is clearly uppercase text.
///
/// After glyph replacement, noise dots between two uppercase letters are
/// stripped (e.g. "[.AZY" → "L.AZY" → "LAZY").
String normalizeBracketAsLetterNoise(String line) {
  int letters = 0;
  int upperLetters = 0;
  int nonSpace = 0;
  for (int i = 0; i < line.length; i++) {
    final int c = line.codeUnitAt(i);
    if (c != spaceCodeUnit) nonSpace++;
    if (isLetter(c)) {
      letters++;
      if (isUpper(c)) upperLetters++;
    }
  }

  if (nonSpace == 0 ||
      letters / nonSpace < _bracketNoiseMinLetterRatio ||
      letters == 0 ||
      upperLetters / letters < _bracketNoiseMinUpperRatio) {
    return line;
  }

  final List<String> tokens = line.split(' ');
  bool changed = false;

  for (int i = 0; i < tokens.length; i++) {
    final String token = tokens[i];
    if (token.isEmpty) continue;

    // Only process tokens that contain a mapped glyph character.
    bool hasGlyph = false;
    for (int j = 0; j < token.length; j++) {
      if (glyphToUpperLetter.containsKey(token[j])) {
        hasGlyph = true;
        break;
      }
    }
    if (!hasGlyph) continue;

    // Replace mapped glyphs with their letter equivalents.
    final StringBuffer buf = StringBuffer();
    for (int j = 0; j < token.length; j++) {
      final String ch = token[j];
      final String? mapped = glyphToUpperLetter[ch];
      buf.write(mapped ?? ch);
    }

    // Strip noise dots between two uppercase letters.
    String result = buf.toString().replaceAllMapped(
      RegExp(r'(?<=[A-Z])\.(?=[A-Z])'),
      (_) => '',
    );

    if (result != token) {
      tokens[i] = result;
      changed = true;
    }
  }

  return changed ? tokens.join(' ') : line;
}

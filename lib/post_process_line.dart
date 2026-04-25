/// Line-level cleanup passes for OCR post-processing.
///
/// Handles noise line detection and merging, short noisy line
/// normalization, and punctuation-heavy text filtering.
library;

import 'package:textify/post_process_helpers.dart';

const int _maxNoiseLineLength = 2;
const int _punctuationFilterShortLineMaxLength = 5;
const double _punctuationHeavyRatioThreshold = 0.4;

/// Merges short noise-only lines into the following content line when useful.
List<String> mergeNoiseLines(List<String> lines) {
  if (lines.isEmpty) {
    return lines;
  }

  final List<String> merged = <String>[];
  int i = 0;
  while (i < lines.length) {
    final String current = lines[i];
    if (_isNoiseLine(current)) {
      if (current.isEmpty) {
        merged.add(current);
      }
      i++;
      continue;
    }

    merged.add(current);
    i++;
  }

  return merged;
}

/// Returns true when a line appears to be OCR noise rather than content.
bool _isNoiseLine(String line) {
  final String trimmed = line.trim();
  if (trimmed.isEmpty) {
    return true;
  }
  if (trimmed.length > _maxNoiseLineLength) {
    return false;
  }

  for (int i = 0; i < trimmed.length; i++) {
    final int code = trimmed.codeUnitAt(i);
    if (isLetter(code) || isDigit(code)) {
      if (!_noiseLetters.contains(trimmed[i])) {
        return false;
      }
      continue;
    }
    if (!_noisePunctuation.contains(trimmed[i])) {
      return false;
    }
  }

  return true;
}

/// Normalizes tiny noisy lines often produced by decorative serif fragments.
List<String> normalizeShortNoisyLines(List<String> lines) {
  return lines;
}

/// Normalizes lines that are overwhelmingly punctuation.
String normalizePunctuationHeavyText(String text) {
  final List<String> lines = text.split('\n');
  final List<String> filtered = <String>[];

  for (final String line in lines) {
    if (line.isEmpty) {
      filtered.add(line);
      continue;
    }

    int punctuation = 0;
    int alphanumeric = 0;
    for (int i = 0; i < line.length; i++) {
      final int code = line.codeUnitAt(i);
      if (isLetter(code) || isDigit(code)) {
        alphanumeric++;
      } else if (line[i] != ' ') {
        punctuation++;
      }
    }

    if (line.length > _punctuationFilterShortLineMaxLength) {
      filtered.add(line);
      continue;
    }

    if (alphanumeric == 0 && punctuation > 0) {
      continue;
    }

    if (punctuation / (punctuation + alphanumeric) >
        _punctuationHeavyRatioThreshold) {
      continue;
    }

    filtered.add(line);
  }

  return filtered.join('\n');
}

const Set<String> _noiseLetters = {'i', 'l', 'I', 'L', 't', 'T'};

const Set<String> _noisePunctuation = {
  '*',
  '-',
  '_',
  '|',
  '!',
  '\'',
  '`',
  '.',
  ',',
};

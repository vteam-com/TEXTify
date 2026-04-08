/// This library is part of the Textify package.
/// Provides post-processing normalization passes for OCR text output.
library;

import 'package:textify/constants.dart';
import 'package:textify/correction.dart';

const int _minLettersForCaseNormalization = 3;
const double _dominantCaseRatio = 0.9;
const int _spaceCodeUnit = 32;
const int _tabCodeUnit = 9;
const int _lineFeedCodeUnit = 10;
const int _carriageReturnCodeUnit = 13;
const int _digitJoinMinCount = 2;
const int _maxNoiseLineLength = 2;
const int _fragmentedLineMinimumTokenCount = 4;
const int _fragmentedLineShortAlphaThreshold = 3;
const int _fragmentPairMinimumTokenCount = 2;
const int _fragmentPairShortWordLength = 3;
const int _fragmentPairLeftLengthWhenRightSingle = 6;
const int _dictionaryCorrectionMinimumTokenLength = 3;
const double _punctuationHeavyRatioThreshold = 0.3;
const double _mostlyUppercaseRatioThreshold = 0.75;
const int _regexGroupFirst = 1;
const int _regexGroupSecond = 2;
const int _uppercaseACodeUnit = 65;
const int _uppercaseZCodeUnit = 90;
const int _lowercaseACodeUnit = 97;
const int _lowercaseZCodeUnit = 122;
const int _digitZeroCodeUnit = 48;
const int _digitNineCodeUnit = 57;
const int _asciiCaseOffset = 32;

/// Applies final normalization passes to OCR text output.
String postProcessText(String text) {
  if (text.isEmpty) {
    return text;
  }

  final List<String> lines = text.split('\n');
  final List<String> processed = <String>[];
  for (final String line in lines) {
    String value = _normalizeLineCase(line);
    value = _normalizeNumericGaps(value);
    value = _normalizeDateSeparators(value);
    value = _normalizeDigitSegments(value);
    value = _normalizeDateSeparators(value);
    value = _normalizeFragmentedLine(value);
    processed.add(value);
  }

  final List<String> merged = _mergeNoiseLines(processed);
  final String joined = _normalizeShortNoisyLines(merged).join('\n');
  final String normalized = _normalizePunctuationHeavyText(joined);
  final String lettersFixed = _normalizeLetterConfusions(normalized);
  return _normalizePunctuationSpacing(lettersFixed);
}

/// Normalizes dominant line casing while preserving mixed-case lines.
String _normalizeLineCase(String line) {
  int letters = 0;
  int upper = 0;
  int lower = 0;
  int? firstLetterCode;

  for (int i = 0; i < line.length; i++) {
    final int code = line.codeUnitAt(i);
    if (_isUpper(code)) {
      letters++;
      upper++;
      firstLetterCode ??= code;
    } else if (_isLower(code)) {
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
    if (_isLower(firstLetterCode)) {
      return _sentenceCase(line);
    }
    return line;
  }

  return line;
}

/// Corrects letter-like confusions inside digit-dominant token segments.
String _normalizeDigitSegments(String line) {
  final StringBuffer out = StringBuffer();
  final StringBuffer buffer = StringBuffer();

  void flushBuffer() {
    if (buffer.isEmpty) {
      return;
    }
    String segment = buffer.toString();
    buffer.clear();

    int digits = 0;
    int letters = 0;
    for (int i = 0; i < segment.length; i++) {
      final int code = segment.codeUnitAt(i);
      if (_isDigit(code)) {
        digits++;
      } else if (_isLetter(code)) {
        letters++;
      }
    }

    if (digits > 0 && digits >= letters) {
      final StringBuffer mapped = StringBuffer();
      for (int i = 0; i < segment.length; i++) {
        final String ch = segment[i];
        mapped.write(_digitConfusionMap[ch] ?? ch);
      }
      segment = mapped.toString();
    }

    out.write(segment);
  }

  for (int i = 0; i < line.length; i++) {
    final int code = line.codeUnitAt(i);
    if (_isLetter(code) || _isDigit(code)) {
      buffer.writeCharCode(code);
    } else {
      flushBuffer();
      out.writeCharCode(code);
    }
  }
  flushBuffer();

  return out.toString();
}

/// Repairs noisy separators and spacing in numeric expressions.
String _normalizeNumericGaps(String line) {
  if (line.isEmpty) {
    return line;
  }

  bool hasNonDigitToken = false;
  for (int i = 0; i < line.length; i++) {
    final int code = line.codeUnitAt(i);
    if (!_isDigit(code) &&
        code != _spaceCodeUnit &&
        code != _tabCodeUnit &&
        code != _lineFeedCodeUnit &&
        code != _carriageReturnCodeUnit) {
      hasNonDigitToken = true;
      break;
    }
  }

  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < line.length; i++) {
    final String ch = line[i];
    final int code = ch.codeUnitAt(0);
    final bool prevDigit = i > 0 && _isDigit(line.codeUnitAt(i - 1));
    final bool nextDigit =
        i + 1 < line.length && _isDigit(line.codeUnitAt(i + 1));

    if (_digitNonAlnumMap.containsKey(ch) && (prevDigit || nextDigit)) {
      buffer.write(_digitNonAlnumMap[ch]);
      continue;
    }

    if (code == _spaceCodeUnit ||
        code == _tabCodeUnit ||
        code == _lineFeedCodeUnit ||
        code == _carriageReturnCodeUnit) {
      buffer.write(ch);
      continue;
    }

    buffer.write(ch);
  }

  final String withMappedNonAlnum = buffer.toString();

  if (!hasNonDigitToken) {
    return withMappedNonAlnum.replaceAll(RegExp(r'\s+'), '');
  }

  return withMappedNonAlnum.replaceAllMapped(
    RegExp(r'(\d)\s+([A-Za-z0-9])(?=\d)'),
    (Match match) {
      final String left = match.group(_regexGroupFirst) ?? '';
      final String mid = match.group(_regexGroupSecond) ?? '';
      final String mapped = _digitConfusionMap[mid] ?? mid;
      return '$left.$mapped';
    },
  );
}

/// Removes OCR-introduced spaces around date separators and digit clusters.
String _normalizeDateSeparators(String line) {
  if (line.isEmpty) {
    return line;
  }

  String value = line.replaceAllMapped(
    RegExp(r'(?<=\d)\s*([./-])\s*(?=\d)'),
    (Match match) => match.group(1) ?? '',
  );
  value = value.replaceAllMapped(RegExp(r'(?<=\d)\s*,\s*(?=\d)'), (_) => ',');

  // Collapse spaces around dots between digits and alphanumeric characters.
  value = value.replaceAllMapped(
    RegExp(r'(?<=\d)\s*\.\s*(?=[A-Za-z0-9])'),
    (_) => '.',
  );
  value = value.replaceAllMapped(
    RegExp(r'(?<=[A-Za-z0-9])\s*\.\s*(?=\d)'),
    (_) => '.',
  );

  // Collapse split numeric runs like "1 2 3" only when there are 2+ joins.
  final RegExp splitDigits = RegExp(r'(?<=\d)\s+(?=\d)');
  final int joins = splitDigits.allMatches(value).length;
  if (joins >= _digitJoinMinCount) {
    value = value.replaceAll(splitDigits, '');
  }
  return value;
}

/// Repairs fragmented words and common letter confusions in noisy lines.
String _normalizeFragmentedLine(String line) {
  if (!_looksFragmented(line)) {
    return line;
  }

  final bool uppercaseDominant = _isMostlyUppercase(line);
  String value = line;
  value = value.replaceAllMapped(
    RegExp(r'(?<=[A-Z])l(?=[A-Z])'),
    (_) => OcrTokens.upperI,
  );
  value = value.replaceAllMapped(
    RegExp(r'(?<=[a-z])I(?=[a-z])'),
    (_) => OcrTokens.lowerL,
  );
  value = value.replaceAllMapped(
    RegExp(r'\b([A-Za-z])\s+([A-Za-z])\b'),
    (Match match) =>
        '${match.group(_regexGroupFirst)}${match.group(_regexGroupSecond)}',
  );
  value = _mergeLikelyWordFragments(value);
  value = _correctNoisyDictionaryWords(value);

  if (uppercaseDominant) {
    value = value.toUpperCase();
  } else {
    value = _sentenceCase(value.toLowerCase());
  }
  return value;
}

/// Normalizes tiny noisy lines often produced by decorative serif fragments.
List<String> _normalizeShortNoisyLines(List<String> lines) {
  return lines;
}

/// Detects lines that likely contain over-segmented words.
bool _looksFragmented(String line) {
  final List<String> tokens = line
      .split(RegExp(r'\s+'))
      .where((String token) => token.isNotEmpty)
      .toList();
  if (tokens.length < _fragmentedLineMinimumTokenCount) {
    return false;
  }

  int shortAlpha = 0;
  for (final String token in tokens) {
    if (RegExp(r'^[A-Za-z]{1,2}$').hasMatch(token)) {
      shortAlpha++;
    }
  }
  return shortAlpha >= _fragmentedLineShortAlphaThreshold;
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
    if (!_isAlphaWord(left) || !_isAlphaWord(right)) {
      i++;
      continue;
    }
    if (left.toLowerCase() == 'a' || right.toLowerCase() == 'a') {
      i++;
      continue;
    }

    final bool likelyFragmentPair =
        (left.length <= _fragmentPairShortWordLength &&
            right.length <= _fragmentPairShortWordLength) ||
        (right.length == _regexGroupFirst &&
            left.length <= _fragmentPairLeftLengthWhenRightSingle);
    if (!likelyFragmentPair) {
      i++;
      continue;
    }

    final String merged = left + right;
    final String suggestion = findClosestMatchingWordInDictionary(merged);
    final int distance = levenshteinDistance(
      merged.toLowerCase(),
      suggestion.toLowerCase(),
    );
    if (distance <= 1) {
      tokens[i] = suggestion;
      tokens.removeAt(i + 1);
      continue;
    }

    i++;
  }

  return tokens.join(' ');
}

/// Corrects near-miss dictionary words in noisy OCR lines.
String _correctNoisyDictionaryWords(String line) {
  final List<String> tokens = line.split(' ');
  for (int i = 0; i < tokens.length; i++) {
    final String token = tokens[i];
    if (!_isAlphaWord(token) ||
        token.length < _dictionaryCorrectionMinimumTokenLength) {
      continue;
    }

    final String suggestion = findClosestMatchingWordInDictionary(token);
    final int distance = levenshteinDistance(
      token.toLowerCase(),
      suggestion.toLowerCase(),
    );
    if (distance <= 1) {
      tokens[i] = suggestion;
    }
  }
  return tokens.join(' ');
}

bool _isAlphaWord(String value) => RegExp(r'^[A-Za-z]+$').hasMatch(value);

/// Returns true when uppercase letters strongly dominate the line.
bool _isMostlyUppercase(String line) {
  int letters = 0;
  int upper = 0;
  for (int i = 0; i < line.length; i++) {
    final int code = line.codeUnitAt(i);
    if (_isUpper(code)) {
      letters++;
      upper++;
      continue;
    }
    if (_isLower(code)) {
      letters++;
    }
  }
  if (letters == 0) {
    return false;
  }
  return (upper / letters) >= _mostlyUppercaseRatioThreshold;
}

/// Merges short noise-only lines into the following content line when useful.
List<String> _mergeNoiseLines(List<String> lines) {
  if (lines.isEmpty) {
    return lines;
  }

  final List<String> merged = <String>[];
  int i = 0;
  while (i < lines.length) {
    final String current = lines[i];
    if (_isNoiseLine(current)) {
      int j = i;
      while (j < lines.length && _isNoiseLine(lines[j])) {
        j++;
      }

      // Skip noise lines — no prefix inference
      i = j;
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
    if (_isLetter(code) || _isDigit(code)) {
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

/// Collapses whitespace when text is dominated by punctuation artifacts.
String _normalizePunctuationHeavyText(String text) {
  int alnum = 0;
  int nonWhitespace = 0;
  for (int i = 0; i < text.length; i++) {
    final int code = text.codeUnitAt(i);
    if (code != _spaceCodeUnit &&
        code != _tabCodeUnit &&
        code != _lineFeedCodeUnit &&
        code != _carriageReturnCodeUnit) {
      nonWhitespace++;
    }
    if (_isLetter(code) || _isDigit(code)) {
      alnum++;
    }
  }

  if (text.isEmpty || nonWhitespace == 0) {
    return text;
  }

  final double ratio = alnum / nonWhitespace;
  if (ratio < _punctuationHeavyRatioThreshold) {
    return text.replaceAll(RegExp(r'\s+'), '');
  }
  return text;
}

/// Removes invalid spaces before punctuation and closing brackets.
String _normalizePunctuationSpacing(String text) {
  if (text.isEmpty) {
    return text;
  }

  String value = text.replaceAllMapped(
    RegExp(r'\s+([,.;:!?])'),
    (match) => match.group(1) ?? '',
  );
  value = value.replaceAllMapped(
    RegExp(r'\s+([)\]\}])'),
    (match) => match.group(1) ?? '',
  );
  return value;
}

/// Fixes known letter-shape confusions produced by OCR segmentation.
String _normalizeLetterConfusions(String text) {
  if (text.isEmpty) {
    return text;
  }

  // Common split of 'H' into 'I]' when the crossbar is faint.
  return text.replaceAllMapped(
    RegExp(r'([A-Za-z])I\]([A-Za-z])'),
    (match) =>
        '${match.group(_regexGroupFirst)}H${match.group(_regexGroupSecond)}',
  );
}

bool _isUpper(int code) =>
    code >= _uppercaseACodeUnit && code <= _uppercaseZCodeUnit;
bool _isLower(int code) =>
    code >= _lowercaseACodeUnit && code <= _lowercaseZCodeUnit;
bool _isLetter(int code) => _isUpper(code) || _isLower(code);
bool _isDigit(int code) =>
    code >= _digitZeroCodeUnit && code <= _digitNineCodeUnit;

/// UpperCases only the first alphabetic character in a line.
String _sentenceCase(String line) {
  final StringBuffer buffer = StringBuffer();
  bool capitalized = false;
  for (int i = 0; i < line.length; i++) {
    final String ch = line[i];
    final int code = ch.codeUnitAt(0);
    if (!capitalized && _isLetter(code)) {
      buffer.writeCharCode(_isLower(code) ? code - _asciiCaseOffset : code);
      capitalized = true;
      continue;
    }
    buffer.write(ch);
  }
  return buffer.toString();
}

const Map<String, String> _digitConfusionMap = {
  'O': '0',
  'o': '0',
  'I': '1',
  'l': '1',
  'L': '1',
  't': '1',
  'T': '1',
  'Z': '2',
  'z': '2',
  'A': '8',
  'a': '8',
  'S': '5',
  's': '5',
};

const Map<String, String> _digitNonAlnumMap = {
  ']': '1',
  '[': '1',
  '|': '1',
  '!': '1',
};

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

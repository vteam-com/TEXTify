/// This library is part of the Textify package.
/// Provides post-processing normalization passes for OCR text output.
library;

import 'package:textify/constants.dart';
import 'package:textify/correction.dart';
import 'package:textify/models/english_words.dart';

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
const int _nearMissMinTokenLength = 4;
const int _nearMissMaxLevenshtein = 1;
const int _nearMissLongTokenLength = 8;
const int _nearMissLongTokenMaxLevenshtein = 2;
const double _punctuationHeavyRatioThreshold = 0.3;
const double _mostlyUppercaseRatioThreshold = 0.75;
const int _nameLikeLineMinTokens = 2;
const int _nameLikeLineMaxTokens = 4;
const int _titleCasePreserveLowerTokenMaxLength = 2;
const int _regexGroupFirst = 1;
const int _regexGroupSecond = 2;
const int _regexGroupThird = 3;
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
    String value = _resolveILAmbiguity(line);
    value = _normalizeWordCaseCoherence(value);
    value = _normalizeLineCase(value);
    value = _normalizeNameLikeLineTitleCase(value);
    value = _normalizeNumericGaps(value);
    value = _normalizeDateSeparators(value);
    value = _normalizeAdjacentDigitLetterConfusions(value);
    value = _normalizeDigitSegments(value);
    value = _normalizeDateSeparators(value);
    value = _normalizeFragmentedLine(value);
    value = _correctNearMissDictionaryWords(value);
    processed.add(value);
  }

  final List<String> merged = _mergeNoiseLines(processed);
  final String joined = _normalizeShortNoisyLines(merged).join('\n');
  final String normalized = _normalizePunctuationHeavyText(joined);
  final String lettersFixed = _normalizeLetterConfusions(normalized);
  return _normalizePunctuationSpacing(lettersFixed);
}

const int _uppercaseICodeUnit = 73;
const int _lowercaseLCodeUnit = 108;
const int _minWordLengthForILAmbiguity = 2;
const int _minWordLengthForCaseCoherence = 3;
const int _minCaseOutlierMajority = 2;

/// Resolves I/l ambiguity based on word-level case context.
///
/// Uppercase 'I' and lowercase 'l' are nearly identical vertical strokes
/// that OCR frequently confuses. When the surrounding letters in a word
/// establish a dominant case, the ambiguous glyph is matched to that case.
String _resolveILAmbiguity(String line) {
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
      } else if (_isUpper(code)) {
        upper++;
      } else if (_isLower(code)) {
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
      return word.replaceAll('I', 'l');
    }

    return word;
  });
}

/// Normalizes stray case-flipped characters within case-consistent words.
///
/// In words of 3+ letters where all but one character share the same case,
/// the outlier is corrected to match. This handles common OCR errors where
/// a single character is recognized in the wrong case.
String _normalizeWordCaseCoherence(String line) {
  return line.replaceAllMapped(RegExp(r'[A-Za-z]+'), (match) {
    final String word = match.group(0)!;
    if (word.length < _minWordLengthForCaseCoherence) {
      return word;
    }

    int upper = 0;
    int lower = 0;
    for (int i = 0; i < word.length; i++) {
      final int code = word.codeUnitAt(i);
      if (_isUpper(code)) {
        upper++;
      } else if (_isLower(code)) {
        lower++;
      }
    }

    final int total = upper + lower;
    if (total < _minWordLengthForCaseCoherence) {
      return word;
    }

    // If all but one character share a case, fix the outlier
    if (upper == 1 && lower >= _minCaseOutlierMajority) {
      // Preserve Title Case (only uppercase is the first letter)
      final int firstCode = word.codeUnitAt(0);
      if (_isUpper(firstCode)) {
        return word;
      }
      return word.toLowerCase();
    }
    if (lower == 1 && upper >= _minCaseOutlierMajority) {
      return word.toUpperCase();
    }

    return word;
  });
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
    return _sentenceCase(line.toLowerCase());
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

/// Converts letters to digits when they appear adjacent to a decimal separator
/// and all letters in the segment have known digit confusion mappings.
///
/// Handles patterns like `24-oo` → `24-00` where OCR confused `0` with `o`
/// in the fractional part of a number.
String _normalizeAdjacentDigitLetterConfusions(String line) {
  return line.replaceAllMapped(
    RegExp(r'(\d+)([.,\-])([A-Za-z]+)(?=\s|$|[^A-Za-z0-9])'),
    (Match match) {
      final String digits = match.group(_regexGroupFirst)!;
      final String sep = match.group(_regexGroupSecond)!;
      final String letters = match.group(_regexGroupThird)!;

      bool allMappable = true;
      final StringBuffer mapped = StringBuffer();
      for (int i = 0; i < letters.length; i++) {
        final String? digit = _digitConfusionMap[letters[i]];
        if (digit != null) {
          mapped.write(digit);
        } else {
          allMappable = false;
          break;
        }
      }

      if (allMappable && letters.isNotEmpty) {
        return '$digits$sep${mapped.toString()}';
      }
      return match.group(0)!;
    },
  );
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
    RegExp(r'(\d)\s+([A-Za-z])(?=\d)'),
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

/// Applies title-case to all words in name-like lines.
///
/// This pass is intentionally narrow: only alphabetic lines with 2-4 tokens
/// where at least one token already looks title-cased and at most one token is
/// fully lowercase. This avoids changing normal sentence lines.
String _normalizeNameLikeLineTitleCase(String line) {
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

  int titleCaseTokens = 0;
  int lowercaseTokens = 0;
  for (final String token in tokens) {
    if (!_isAlphaWord(token)) {
      return line;
    }

    if (_isTitleCaseWord(token)) {
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
    normalized.add(_toTitleCaseWord(token));
  }

  return normalized.join(' ');
}

/// Corrects near-miss dictionary words with strict edit-distance limits.
String _correctNearMissDictionaryWords(String line) {
  if (line.isEmpty) {
    return line;
  }

  return line.replaceAllMapped(RegExp(r'[A-Za-z]+'), (Match match) {
    final String token = match.group(0)!;
    if (token.length < _nearMissMinTokenLength) {
      return token;
    }
    if (token == token.toUpperCase()) {
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
    final int maxAllowed = token.length >= _nearMissLongTokenLength
        ? _nearMissLongTokenMaxLevenshtein
        : _nearMissMaxLevenshtein;
    if (distance > maxAllowed) {
      return token;
    }
    if ((suggestion.length - token.length).abs() > 1) {
      return token;
    }

    if (_isTitleCaseWord(token)) {
      return _toTitleCaseWord(suggestion);
    }
    if (token == token.toLowerCase()) {
      return suggestion.toLowerCase();
    }
    return suggestion;
  });
}

/// Returns true when [word] follows strict ASCII title-case.
///
/// A strict title-case word has an uppercase first letter and lowercase
/// letters for all remaining characters.
bool _isTitleCaseWord(String word) {
  if (word.isEmpty) {
    return false;
  }

  final int first = word.codeUnitAt(0);
  if (!_isUpper(first)) {
    return false;
  }

  for (int i = 1; i < word.length; i++) {
    final int code = word.codeUnitAt(i);
    if (!_isLower(code)) {
      return false;
    }
  }

  return true;
}

/// Converts [word] to strict ASCII title-case.
///
/// The result has an uppercase first letter and lowercase remaining letters.
String _toTitleCaseWord(String word) {
  if (word.isEmpty) {
    return word;
  }

  final String lower = word.toLowerCase();
  if (lower.length == 1) {
    return lower.toUpperCase();
  }

  return '${lower[0].toUpperCase()}${lower.substring(1)}';
}

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

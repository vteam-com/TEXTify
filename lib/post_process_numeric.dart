/// Numeric normalization passes for OCR post-processing.
///
/// Handles digit segment corrections, numeric gap repair,
/// and date separator normalization.
library;

import 'package:textify/post_process_helpers.dart';

const int _digitJoinMinCount = 2;
const int _maxShortLetterSegmentLength = 2;
const int _gridLikeRowMinNumericPeers = 2;
const int _gridLikeRowMinTokenLength = 3;
const int _structuredFieldLabelGroup = 1;
const int _structuredFieldValueGroup = 2;
const int _structuredFieldMaxLabelWords = 3;
const int _structuredDecimalFractionLength = 2;

/// Normalizes numeric-like values in simple structured field lines.
///
/// This targets lines like `Date: zoz5-06-15` and `Amount: ], z5o.75`, where
/// the label is alphabetic and the value has a date-like or decimal-like
/// numeric shape polluted only by OCR digit lookalikes.
String normalizeStructuredNumericFieldValue(String line) {
  if (line.isEmpty) {
    return line;
  }

  final Match? match = RegExp(
    r'^\s*([A-Za-z]+(?:\s+[A-Za-z]+){0,2})\s*:\s*(.+?)\s*$',
  ).firstMatch(line);
  if (match == null) {
    return line;
  }

  final String label = match.group(_structuredFieldLabelGroup) ?? '';
  final String rawValue = match.group(_structuredFieldValueGroup) ?? '';
  if (label.isEmpty || rawValue.isEmpty) {
    return line;
  }

  final int labelWordCount = label
      .split(RegExp(r'\s+'))
      .where((String token) => token.isNotEmpty)
      .length;
  if (labelWordCount == 0 || labelWordCount > _structuredFieldMaxLabelWords) {
    return line;
  }

  String? normalizedValue;
  if (_looksDateLikeStructuredNumericValue(rawValue)) {
    normalizedValue = normalizeDateSeparators(
      _mapDigitLookalikesInValue(rawValue),
    );
  } else if (_looksDecimalStructuredNumericValue(rawValue)) {
    normalizedValue = normalizeDateSeparators(
      _mapDigitLookalikesInValue(rawValue),
    );
  }

  if (normalizedValue == null || normalizedValue == rawValue) {
    return line;
  }

  return '$label: $normalizedValue';
}

/// Normalizes standalone decimal-like tokens made only of digit lookalikes.
///
/// This reuses the same decimal-shape validator as structured fields, but
/// applies it to free-standing tokens in prose such as `O.OO USD`.
String normalizeStandaloneDecimalLikeToken(String line) {
  if (line.isEmpty) {
    return line;
  }

  return line.replaceAllMapped(
    RegExp(
      r'(?<![A-Za-z0-9])([\[\]|!A-Za-z0-9]+\.[A-Za-z0-9]{2})(?![A-Za-z0-9])',
    ),
    (Match match) {
      final String token = match.group(regexGroupFirst) ?? '';
      if (!_looksDecimalStructuredNumericValue(token)) {
        return token;
      }
      return normalizeDateSeparators(_mapDigitLookalikesInValue(token));
    },
  );
}

/// Corrects letter-like confusions inside digit-dominant token segments.
String normalizeDigitSegments(String line) {
  // Split line into alternating alnum-segments and separators.
  final List<String> tokens = [];
  final List<bool> tokenIsAlnum = [];
  final StringBuffer buf = StringBuffer();
  bool? currentAlnum;

  for (int i = 0; i < line.length; i++) {
    final int code = line.codeUnitAt(i);
    final bool alnum = isLetter(code) || isDigit(code);
    if (currentAlnum != null && alnum != currentAlnum) {
      tokens.add(buf.toString());
      tokenIsAlnum.add(currentAlnum);
      buf.clear();
    }
    buf.writeCharCode(code);
    currentAlnum = alnum;
  }
  if (buf.isNotEmpty && currentAlnum != null) {
    tokens.add(buf.toString());
    tokenIsAlnum.add(currentAlnum);
  }

  bool isDigitDominant(String s) {
    int d = 0, l = 0;
    for (int i = 0; i < s.length; i++) {
      final int c = s.codeUnitAt(i);
      if (isDigit(c)) {
        d++;
      } else if (isLetter(c)) {
        l++;
      }
    }
    return d > 0 && d >= l;
  }

  bool isAllLetters(String s) {
    for (int i = 0; i < s.length; i++) {
      if (!isLetter(s.codeUnitAt(i))) return false;
    }
    return s.isNotEmpty;
  }

  final StringBuffer out = StringBuffer();
  for (int ti = 0; ti < tokens.length; ti++) {
    if (!tokenIsAlnum[ti]) {
      out.write(tokens[ti]);
      continue;
    }

    String segment = tokens[ti];
    int digits = 0, letters = 0;
    for (int i = 0; i < segment.length; i++) {
      final int c = segment.codeUnitAt(i);
      if (isDigit(c)) {
        digits++;
      } else if (isLetter(c)) {
        letters++;
      }
    }

    if (digits > 0 && digits >= letters) {
      // Digit-dominant: convert letters adjacent to at least one digit.
      final StringBuffer mapped = StringBuffer();
      for (int i = 0; i < segment.length; i++) {
        final int code = segment.codeUnitAt(i);
        if (isLetter(code)) {
          final bool prevDig = i > 0 && isDigit(segment.codeUnitAt(i - 1));
          final bool nextDig =
              i + 1 < segment.length && isDigit(segment.codeUnitAt(i + 1));
          if (prevDig || nextDig) {
            mapped.write(digitConfusionMap[segment[i]] ?? segment[i]);
          } else {
            mapped.write(segment[i]);
          }
        } else {
          mapped.write(segment[i]);
        }
      }
      segment = mapped.toString();
    } else if (isAllLetters(segment) &&
        (_isGridLikeDigitToken(
              tokens,
              tokenIsAlnum,
              ti,
              segment,
              isDigitDominant,
            ) ||
            segment.length <= _maxShortLetterSegmentLength)) {
      // Short all-letter segment near digit-dominant neighbors
      // e.g. "2020-Ol-02" → "Ol" between "2020" and "02" → "01".
      bool prevDigit = false, nextDigit = false;
      for (int p = ti - 1; p >= 0; p--) {
        if (tokenIsAlnum[p]) {
          prevDigit = isDigitDominant(tokens[p]);
          break;
        }
      }
      for (int n = ti + 1; n < tokens.length; n++) {
        if (tokenIsAlnum[n]) {
          nextDigit = isDigitDominant(tokens[n]);
          break;
        }
      }
      // Both neighbors digit-dominant → always convert.
      // Single neighbor digit-dominant → only convert when every
      // character is a high-confidence digit lookalike (O, l, I, S, Z).
      bool convert = false;
      if (prevDigit && nextDigit) {
        convert = true;
      } else if (prevDigit || nextDigit) {
        convert = true;
        for (int i = 0; i < segment.length; i++) {
          if (!highConfidenceDigitLookalikes.contains(segment[i])) {
            convert = false;
            break;
          }
        }
      }
      if (convert) {
        final StringBuffer mapped = StringBuffer();
        for (int i = 0; i < segment.length; i++) {
          mapped.write(digitConfusionMap[segment[i]] ?? segment[i]);
        }
        segment = mapped.toString();
      }
    }

    out.write(segment);
  }

  return out.toString();
}

/// Returns true when [segment] looks like a digit cell inside a numeric grid.
///
/// This catches rows like `IOOI 2002 3003`, where one token is all letters but
/// has the same width as neighboring numeric cells and is composed entirely of
/// high-confidence digit lookalikes.
bool _isGridLikeDigitToken(
  List<String> tokens,
  List<bool> tokenIsAlnum,
  int tokenIndex,
  String segment,
  bool Function(String) isDigitDominant,
) {
  if (segment.length < _gridLikeRowMinTokenLength) {
    return false;
  }

  for (int i = 0; i < segment.length; i++) {
    if (!highConfidenceDigitLookalikes.contains(segment[i])) {
      return false;
    }
  }

  int matchingNumericPeers = 0;
  for (int i = 0; i < tokens.length; i++) {
    if (i == tokenIndex || !tokenIsAlnum[i]) {
      continue;
    }
    if (tokens[i].length == segment.length && isDigitDominant(tokens[i])) {
      matchingNumericPeers++;
    }
  }

  return matchingNumericPeers >= _gridLikeRowMinNumericPeers;
}

/// Repairs noisy separators and spacing in numeric expressions.
///
/// Handles cases like "1 . 23" -> "1.23" and detects digit-dominant lines
/// to remove all whitespace.
String normalizeNumericGaps(String line) {
  if (line.isEmpty) {
    return line;
  }

  bool hasNonDigitToken = false;
  for (int i = 0; i < line.length; i++) {
    final int code = line.codeUnitAt(i);
    if (!isDigit(code) &&
        code != spaceCodeUnit &&
        code != tabCodeUnit &&
        code != lineFeedCodeUnit &&
        code != carriageReturnCodeUnit) {
      hasNonDigitToken = true;
      break;
    }
  }

  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < line.length; i++) {
    final String ch = line[i];
    final int code = ch.codeUnitAt(0);
    final bool prevDigit = i > 0 && isDigit(line.codeUnitAt(i - 1));
    final bool nextDigit =
        i + 1 < line.length && isDigit(line.codeUnitAt(i + 1));

    if (digitNonAlnumMap.containsKey(ch) && (prevDigit || nextDigit)) {
      buffer.write(digitNonAlnumMap[ch]);
      continue;
    }

    if (code == spaceCodeUnit ||
        code == tabCodeUnit ||
        code == lineFeedCodeUnit ||
        code == carriageReturnCodeUnit) {
      buffer.write(ch);
      continue;
    }

    buffer.write(ch);
  }

  final String withMappedNonAlnum = buffer.toString();

  if (!hasNonDigitToken) {
    // Only collapse whitespace when every digit group is a single digit,
    // which suggests a fragmented number (e.g. "1 2 3 4" → "1234").
    // Multi-digit groups separated by spaces are distinct numbers
    // (e.g. "4004 5005 6006") and should keep their spaces.
    if (_allSingleDigitGroups(withMappedNonAlnum)) {
      return withMappedNonAlnum.replaceAll(RegExp(r'\s+'), '');
    }
    return withMappedNonAlnum;
  }

  return withMappedNonAlnum.replaceAllMapped(
    RegExp(r'(\d)\s+([A-Za-z])(?=\d)'),
    (Match match) {
      final String left = match.group(regexGroupFirst) ?? '';
      final String mid = match.group(regexGroupSecond) ?? '';
      final String mapped = digitConfusionMap[mid] ?? mid;
      return '$left.$mapped';
    },
  );
}

/// Removes OCR-introduced spaces around date separators and digit clusters.
String normalizeDateSeparators(String line) {
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

  // Collapse split numeric runs like "1 2 3" only when there are 2+ joins
  // and all digit groups are single digits (fragmented number, not a column
  // of distinct numbers).
  final RegExp splitDigits = RegExp(r'(?<=\d)\s+(?=\d)');
  final int joins = splitDigits.allMatches(value).length;
  if (joins >= _digitJoinMinCount && _allSingleDigitGroups(value)) {
    value = value.replaceAll(splitDigits, '');
  }
  return value;
}

/// Returns true when [value] has a date-like numeric shape with only
/// digit-lookalike alphabetic noise.
bool _looksDateLikeStructuredNumericValue(String value) {
  if (!RegExp(
    r'^[A-Za-z0-9]{1,4}(?:\s*[./-]\s*[A-Za-z0-9]{1,4}){2,}$',
  ).hasMatch(value)) {
    return false;
  }

  int digitCount = 0;
  int letterCount = 0;
  for (int i = 0; i < value.length; i++) {
    final String ch = value[i];
    final int code = value.codeUnitAt(i);
    if (isDigit(code)) {
      digitCount++;
    } else if (isLetter(code)) {
      letterCount++;
      if (!digitConfusionMap.containsKey(ch)) {
        return false;
      }
    }
  }

  return digitCount > 0 && digitCount >= letterCount;
}

/// Returns true when [value] has a decimal-number shape with only
/// digit-lookalike alphabetic or punctuation noise.
bool _looksDecimalStructuredNumericValue(String value) {
  if (!RegExp(r'^[\[\]|!,\sA-Za-z0-9]+\.[A-Za-z0-9]{2}$').hasMatch(value)) {
    return false;
  }

  int digitLikeCount = 0;
  for (int i = 0; i < value.length; i++) {
    final String ch = value[i];
    final int code = value.codeUnitAt(i);
    if (isDigit(code) ||
        digitConfusionMap.containsKey(ch) ||
        digitNonAlnumMap.containsKey(ch)) {
      digitLikeCount++;
      continue;
    }
    if (isLetter(code)) {
      return false;
    }
  }

  final Match? fractionMatch = RegExp(r'\.([A-Za-z0-9]+)$').firstMatch(value);
  if (fractionMatch == null) {
    return false;
  }

  final String fraction = fractionMatch.group(regexGroupFirst) ?? '';
  return digitLikeCount > _structuredDecimalFractionLength &&
      fraction.length == _structuredDecimalFractionLength;
}

/// Maps OCR digit-lookalike letters and symbols across an already validated
/// numeric-like field value.
String _mapDigitLookalikesInValue(String value) {
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < value.length; i++) {
    final String ch = value[i];
    if (digitConfusionMap.containsKey(ch)) {
      buffer.write(digitConfusionMap[ch]);
    } else if (digitNonAlnumMap.containsKey(ch)) {
      buffer.write(digitNonAlnumMap[ch]);
    } else {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}

/// Map of letters commonly confused with digits by OCR.
const Map<String, String> digitConfusionMap = {
  'O': '0',
  'o': '0',
  'I': '1',
  'i': '1',
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

/// Map of non-alphanumeric characters commonly confused with digits.
const Map<String, String> digitNonAlnumMap = {
  ']': '1',
  '[': '1',
  '|': '1',
  '!': '1',
};

/// Letters that are high-confidence digit lookalikes — safe to convert to
/// digits even with only one digit-dominant neighbor.
const Set<String> highConfidenceDigitLookalikes = {
  'O', 'o', // → 0
  'I', 'i', 'l', 'L', // -> 1
  'S', 's', // → 5
  'Z', 'z', // → 2
};

/// Returns true when every digit group in [text] is a single digit.
///
/// A line like "1 2 3 4" (all single-digit groups) is likely a fragmented
/// number and should be collapsed to "1234". A line like "4004 5005 6006"
/// has multi-digit groups that are distinct numbers and should keep spaces.
bool _allSingleDigitGroups(String text) {
  final Iterable<Match> groups = RegExp(r'\d+').allMatches(text);
  for (final Match group in groups) {
    if (group.end - group.start > 1) {
      return false;
    }
  }
  return true;
}

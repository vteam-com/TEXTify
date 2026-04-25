/// Numeric normalization passes for OCR post-processing.
///
/// Handles digit segment corrections, numeric gap repair,
/// and date separator normalization.
library;

import 'package:textify/post_process_helpers.dart';

const int _digitJoinMinCount = 2;
const int _maxShortLetterSegmentLength = 2;

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
        segment.length <= _maxShortLetterSegmentLength) {
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
    return withMappedNonAlnum.replaceAll(RegExp(r'\s+'), '');
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

  // Collapse split numeric runs like "1 2 3" only when there are 2+ joins.
  final RegExp splitDigits = RegExp(r'(?<=\d)\s+(?=\d)');
  final int joins = splitDigits.allMatches(value).length;
  if (joins >= _digitJoinMinCount) {
    value = value.replaceAll(splitDigits, '');
  }
  return value;
}

/// Map of letters commonly confused with digits by OCR.
const Map<String, String> digitConfusionMap = {
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
  'I', 'l', 'L', // → 1
  'S', 's', // → 5
  'Z', 'z', // → 2
};

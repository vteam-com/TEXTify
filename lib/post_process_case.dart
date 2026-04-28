/// Case normalization passes for OCR post-processing.
///
/// Handles I/L ambiguity resolution, word-level case coherence,
/// line-level case normalization, and name-like title-case formatting.
library;

import 'package:textify/correction.dart' show findClosestWord, isOcrConfusionPair, levenshteinDistance;
import 'package:textify/models/english_words.dart';
import 'package:textify/post_process_helpers.dart';

const int _minLettersForCaseNormalization = 3;
const double _dominantCaseRatio = 0.9;
const int _uppercaseICodeUnit = 73;
const int _lowercaseLCodeUnit = 108;
const int _minWordLengthForILAmbiguity = 2;
const int _minWordLengthForCaseCoherence = 3;
const int _nameLikeLineMinTokens = 2;
const int _nameLikeLineMaxTokens = 4;
const int _titleCasePreserveLowerTokenMaxLength = 2;
const int _shortUppercaseDictionaryTokenLength = 2;
const int _sentenceLikeLowercaseTokenMinCount = 2;
const int _sentenceLikeTitleCaseTokenMaxCount = 1;
const int _longLowercaseProseMinTokens = 6;
const int _longLowercaseProseMinLetters = 24;
const int _structuredFieldLabelMaxWords = 3;
const int _structuredFieldValueMinWords = 2;
const int _structuredFieldValueMaxWords = 4;
const int _structuredCodeLabelMinLength = 2;
const int _structuredCodeLabelMaxLength = 3;
const int _structuredLongMixedCodeTokenMinLength = 6;
const int _structuredCodePrefixMinLength = 2;
const int _structuredCodePrefixMaxLength = 3;
const int _structuredCodeSuffixGroup = 3;
const int _normalizableCodeTokenMinCompactLength = 6;
const int _compoundCodePrefixMinLength = 2;
const int _compoundCodePrefixMaxLength = 4;
const int _compoundCodeMiddleMinDigits = 6;
const int _compoundCodeSuffixMinDigits = 4;
const int _compoundCodePartCount = 3;
const int _compoundCodePrefixPartIndex = 0;
const int _compoundCodeMiddlePartIndex = 1;
const int _compoundCodeSuffixPartIndex = 2;
const int _structuredStatusValueMinLength = 4;
const int _structuredStatusValueMaxDistance = 4;
const int _nameLikeTokenMaxDistance = 2;

const Map<String, String> _codeDigitLookalikeMap = {
  'O': '0',
  'o': '0',
  'I': '1',
  'l': '1',
  'L': '1',
  'S': '5',
  's': '5',
  'Z': '2',
  'z': '2',
};

/// Resolves I/l ambiguity based on word-level case context.
///
/// Uppercase 'I' and lowercase 'l' are nearly identical vertical strokes
/// that OCR frequently confuses. When the surrounding letters in a word
/// establish a dominant case, the ambiguous glyph is matched to that case.
///
/// Positional exceptions:
///  - An 'I' at the START of a word is never changed: it could be a
///    capitalized word like "In" or "Is".
///  - An 'I' preceded by another uppercase letter is never changed: it
///    is likely part of an acronym suffix like "OpenAI" or "GPT-4I".
String resolveILAmbiguity(String line) {
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
      } else if (isUpper(code)) {
        upper++;
      } else if (isLower(code)) {
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
      // Only convert I→l when the I is clearly in a lowercase context:
      // skip I at position 0 (could be a capitalized word like "In")
      // and skip I preceded by an uppercase letter (acronym like "OpenAI").
      final StringBuffer sb = StringBuffer();
      for (int i = 0; i < word.length; i++) {
        final int code = word.codeUnitAt(i);
        if (code == _uppercaseICodeUnit) {
          final bool atStart = i == 0;
          final bool afterUpper = i > 0 && isUpper(word.codeUnitAt(i - 1));
          if (atStart || afterUpper) {
            sb.writeCharCode(code); // keep as I
          } else {
            sb.write('l'); // convert to l
          }
        } else {
          sb.writeCharCode(code);
        }
      }
      return sb.toString();
    }

    return word;
  });
}

/// Normalizes stray case-flipped characters within case-consistent words.
///
/// In words of 3+ letters where all but one character share the same case,
/// the outlier is corrected to match. This handles common OCR errors where
/// a single character is recognized in the wrong case.
String normalizeWordCaseCoherence(String line) {
  return line.replaceAllMapped(RegExp(r'[A-Za-z]+'), (match) {
    final String word = match.group(0)!;
    if (word.length < _minWordLengthForCaseCoherence) {
      return word;
    }

    int upper = 0;
    int lower = 0;
    for (int i = 0; i < word.length; i++) {
      final int code = word.codeUnitAt(i);
      if (isUpper(code)) {
        upper++;
      } else if (isLower(code)) {
        lower++;
      }
    }

    final int total = upper + lower;
    if (total < _minWordLengthForCaseCoherence) {
      return word;
    }

    // If one case is strongly dominant, normalize the word
    if (total >= _minWordLengthForCaseCoherence) {
      if (upper >= total - 1 && upper > lower) {
        return word.toUpperCase();
      }
      if (lower >= total - 1 && lower > upper) {
        // Preserve Title Case
        if (isUpper(word.codeUnitAt(0))) {
          return sentenceCase(word.toLowerCase());
        }
        return word.toLowerCase();
      }
    }

    return word;
  });
}

/// Normalizes dominant line casing while preserving mixed-case lines.
String normalizeLineCase(String line) {
  if (hasCodeLikeToken(line)) {
    return line;
  }

  int letters = 0;
  int upper = 0;
  int lower = 0;
  int? firstLetterCode;

  for (int i = 0; i < line.length; i++) {
    final int code = line.codeUnitAt(i);
    if (isUpper(code)) {
      letters++;
      upper++;
      firstLetterCode ??= code;
    } else if (isLower(code)) {
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
    final String lowercased = line.toLowerCase();
    if (shouldPreserveLongLowercaseProse(
      line,
      minTokens: _longLowercaseProseMinTokens,
      minLetters: _longLowercaseProseMinLetters,
    )) {
      return lowercased;
    }
    return sentenceCase(lowercased);
  }

  return line;
}

/// Applies title-case to all words in name-like lines.
///
/// This pass is intentionally narrow: only alphabetic lines with 2-4 tokens
/// where at least one token already looks title-cased and at most one token is
/// fully lowercase. This avoids changing normal sentence lines.
String normalizeNameLikeLineTitleCase(String line) {
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
  int mixedCaseTokens = 0;
  for (final String token in tokens) {
    if (!isAlphaWord(token)) {
      return line;
    }

    if (isTitleCaseWord(token)) {
      titleCaseTokens++;
      continue;
    }

    if (token == token.toLowerCase()) {
      lowercaseTokens++;
      continue;
    }

    if (isMixedCase(token)) {
      mixedCaseTokens++;
      continue;
    }

    return line;
  }

  if (titleCaseTokens == 0 || lowercaseTokens > 1 || mixedCaseTokens > 1) {
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

    if (isMixedCase(token) && _countUppercaseAfterStart(token) > 1) {
      normalized.add(token);
      continue;
    }

    final String repaired = _normalizeNameLikeToken(token);
    if (isMixedCase(token) && repaired == token) {
      normalized.add(token);
      continue;
    }

    normalized.add(toTitleCaseWord(repaired));
  }

  return normalized.join(' ');
}

int _countUppercaseAfterStart(String token) {
  int count = 0;
  for (int i = 1; i < token.length; i++) {
    if (isUpper(token.codeUnitAt(i))) {
      count++;
    }
  }
  return count;
}

/// Lowercases short all-caps dictionary words inside sentence-like lines.
///
/// This targets OCR leftovers like `IS` in prose lines such as
/// `Your balance IS now 0.00 USD.` without touching title-case phrases,
/// mixed-case brands, or longer acronyms such as `USD`.
String normalizeShortUppercaseDictionaryWords(String line) {
  if (line.isEmpty || hasCodeLikeToken(line)) {
    return line;
  }

  final Iterable<Match> matches = RegExp(r'[A-Za-z]+').allMatches(line);
  int lowercaseTokenCount = 0;
  int titleCaseLikeTokenCount = 0;
  for (final Match match in matches) {
    final String token = match.group(0)!;
    if (token == token.toLowerCase()) {
      lowercaseTokenCount++;
    } else if (isTitleCaseWord(token) || isMixedCase(token)) {
      titleCaseLikeTokenCount++;
    }
  }

  if (lowercaseTokenCount < _sentenceLikeLowercaseTokenMinCount ||
      titleCaseLikeTokenCount > _sentenceLikeTitleCaseTokenMaxCount) {
    return line;
  }

  return line.replaceAllMapped(RegExp(r'\b([A-Z]{2})\b'), (Match match) {
    final String token = match.group(regexGroupFirst)!;
    if (token.length != _shortUppercaseDictionaryTokenLength ||
        !englishWords.contains(token.toLowerCase())) {
      return token;
    }
    return token.toLowerCase();
  });
}

/// Normalizes mixed alphanumeric code-like tokens without touching prose.
///
/// This uppercases alphabetic code segments, converts digit-lookalike letters
/// at the start of digit runs, and restores hyphen separators in simple
/// compound IDs such as `ORD+20250615+0042`.
String normalizeCodeLikeTokens(String line) {
  if (!hasCodeLikeToken(line)) {
    return line;
  }

  return line.replaceAllMapped(
    RegExp(r'[A-Za-z0-9][A-Za-z0-9+\-/:]*[A-Za-z0-9]'),
    (Match match) {
      final String token = match.group(0)!;
      if (!_looksNormalizableCodeToken(token)) {
        return token;
      }
      return _normalizeCodeLikeToken(token);
    },
  );
}

/// Normalizes simple structured field lines such as `Name: john smith`.
///
/// This preserves common OCR output for label/value layouts without changing
/// general prose. The label is title-cased when it is purely alphabetic, and
/// the value is title-cased only when it is a multi-word alphabetic phrase.
String normalizeStructuredFieldLine(
  String line, {
  required bool applyDictionary,
}) {
  final String colonNormalized = _normalizeMissingStructuredFieldColon(line);
  final Match? match = RegExp(
    r'^\s*([A-Za-z]+(?:\s+[A-Za-z]+){0,2})\s*:\s*(.+?)\s*$',
  ).firstMatch(colonNormalized);
  if (match == null) {
    return colonNormalized;
  }

  final String rawLabel = match.group(1) ?? '';
  final String rawValue = match.group(regexGroupSecond) ?? '';
  if (rawLabel.isEmpty || rawValue.isEmpty) {
    return colonNormalized;
  }

  final List<String> labelTokens = rawLabel
      .split(RegExp(r'\s+'))
      .where((String token) => token.isNotEmpty)
      .toList();
  if (labelTokens.isEmpty ||
      labelTokens.length > _structuredFieldLabelMaxWords) {
    return line;
  }

  if (!labelTokens.every(isAlphaWord)) {
    return line;
  }

  final bool preserveUppercaseCodeLabel =
      labelTokens.length == 1 &&
      _isUppercaseCodeLabel(labelTokens.first) &&
      _looksStructuredCodeLikeValue(rawValue);

  final String normalizedLabel = preserveUppercaseCodeLabel
      ? labelTokens.first.toUpperCase()
      : labelTokens
            .map(
              (String token) => _normalizeStructuredLabelToken(
                token,
                applyDictionary: applyDictionary,
              ),
            )
            .map((String token) => toTitleCaseWord(token))
            .join(' ');

  String normalizedValue = rawValue;
  final List<String> valueTokens = rawValue
      .split(RegExp(r'\s+'))
      .where((String token) => token.isNotEmpty)
      .toList();
  final bool nameLikeLabel =
      applyDictionary &&
      labelTokens.length == 1 &&
      labelTokens.first.toLowerCase() == 'name';
  final bool alphaPhrase =
      valueTokens.length >= _structuredFieldValueMinWords &&
      valueTokens.length <= _structuredFieldValueMaxWords &&
      valueTokens.every(isAlphaWord);
  if (alphaPhrase) {
    normalizedValue = valueTokens
        .map(
          (String token) =>
              nameLikeLabel ? _normalizeNameLikeToken(token) : token,
        )
        .map((String token) => toTitleCaseWord(token))
        .join(' ');
  }

  final bool statusLikeLabel =
      applyDictionary &&
      labelTokens.length == 1 &&
      labelTokens.first.toLowerCase() == 'status' &&
      valueTokens.length == 1 &&
      isAlphaWord(valueTokens.first);
  if (statusLikeLabel) {
    normalizedValue = _normalizeStructuredStatusValue(valueTokens.first);
  }

  normalizedValue = _normalizeStructuredCodeValue(normalizedValue);

  return '$normalizedLabel: $normalizedValue';
}

/// Repairs a likely name token using the shared English dictionary.
///
/// This stays scoped to name-like lines and `Name:` fields, but avoids any
/// dedicated name-only lexicon by using the normal dictionary source.
String _normalizeNameLikeToken(String token) {
  if (!isAlphaWord(token)) {
    return token;
  }

  final String lower = token.toLowerCase();
  if (englishWords.contains(lower)) {
    return lower;
  }

  final String suggestion = findClosestWord(englishWords, lower);
  if (suggestion.length != token.length ||
      levenshteinDistance(lower, suggestion) > _nameLikeTokenMaxDistance) {
    return token;
  }

  return suggestion;
}

/// Normalizes single-word `Status:` field values to a known uppercase status.
///
/// When the OCR result is close to a supported status word such as
/// `CONFIRMED`, this restores the canonical uppercase form while leaving
/// unrelated values alone.
String _normalizeStructuredStatusValue(String value) {
  final String lower = value.toLowerCase();
  if (value.length < _structuredStatusValueMinLength) {
    return value;
  }

  if (englishWords.contains(lower)) {
    return lower.toUpperCase();
  }

  final String suggestion = findClosestWord(englishWords, lower);
  if (suggestion.length != value.length ||
      levenshteinDistance(lower, suggestion) >
          _structuredStatusValueMaxDistance) {
    return value;
  }

  return suggestion.toUpperCase();
}

/// Restores a missing colon after short uppercase labels in code-like rows.
///
/// OCR can read `SKU:` or `LOT:` as `SKUI` / `LOTI`. This converts the
/// trailing `I` back into a colon only when the remainder of the line still
/// looks like a structured code value.
String _normalizeMissingStructuredFieldColon(String line) {
  final Match? match = RegExp(
    r'^\s*([A-Z]{2,3})I\s+(.+?)\s*$',
  ).firstMatch(line);
  if (match == null) {
    return line;
  }

  final String label = match.group(regexGroupFirst) ?? '';
  final String value = match.group(regexGroupSecond) ?? '';
  if (!_isUppercaseCodeLabel(label) || !_looksStructuredCodeLikeValue(value)) {
    return line;
  }

  return '$label: $value';
}

/// Returns true when [label] is a short all-uppercase code field label.
bool _isUppercaseCodeLabel(String label) {
  return label.length >= _structuredCodeLabelMinLength &&
      label.length <= _structuredCodeLabelMaxLength &&
      label == label.toUpperCase() &&
      isAlphaWord(label);
}

/// Returns true when [value] has a code-like structured identifier shape.
bool _looksStructuredCodeLikeValue(String value) {
  if (RegExp(r'[-/:]').hasMatch(value)) {
    return true;
  }

  for (final String token in value.split(RegExp(r'\s+'))) {
    final String compact = token.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (compact.length < _structuredLongMixedCodeTokenMinLength) {
      continue;
    }

    bool hasLetter = false;
    bool hasDigit = false;
    for (int i = 0; i < compact.length; i++) {
      final int code = compact.codeUnitAt(i);
      if (isLetter(code)) {
        hasLetter = true;
      } else if (isDigit(code)) {
        hasDigit = true;
      }
    }

    if (hasLetter && hasDigit) {
      return true;
    }
  }

  return false;
}

/// Uppercases short alphabetic prefixes in structured code values.
///
/// This targets fields like `Reference: Tx-98432`, where OCR preserves the
/// code structure but weakens the prefix casing. Only short prefixes attached
/// to digit-led identifier bodies are normalized, so prose values are left
/// alone.
String _normalizeStructuredCodeValue(String value) {
  final Match? match = RegExp(
    r'^([A-Za-z]{2,3})([-/])(\d[A-Za-z0-9/-]*)$',
  ).firstMatch(value);
  if (match == null) {
    return value;
  }

  final String prefix = match.group(regexGroupFirst) ?? '';
  final String separator = match.group(regexGroupSecond) ?? '';
  final String suffix = match.group(_structuredCodeSuffixGroup) ?? '';
  if (prefix.length < _structuredCodePrefixMinLength ||
      prefix.length > _structuredCodePrefixMaxLength ||
      separator.isEmpty ||
      suffix.isEmpty) {
    return value;
  }

  return '${prefix.toUpperCase()}$separator$suffix';
}

/// Returns true when [token] is a compact mixed alphanumeric code token.
bool _looksNormalizableCodeToken(String token) {
  final String compact = token.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (compact.length < _normalizableCodeTokenMinCompactLength) {
    return false;
  }

  bool hasLetter = false;
  bool hasDigit = false;
  for (int i = 0; i < compact.length; i++) {
    final int code = compact.codeUnitAt(i);
    if (isLetter(code)) {
      hasLetter = true;
    } else if (isDigit(code)) {
      hasDigit = true;
    }
  }

  return hasLetter && hasDigit;
}

/// Normalizes a single compact code-like [token].
String _normalizeCodeLikeToken(String token) {
  final List<String> parts = token
      .splitMapJoin(
        RegExp(r'([+\-/:])'),
        onMatch: (Match match) => '¤${match.group(0)!}¤',
        onNonMatch: (String part) => '¤$part¤',
      )
      .split('¤')
      .where((String part) => part.isNotEmpty)
      .toList();

  final List<String> normalized = <String>[];
  for (final String part in parts) {
    if (RegExp(r'^[+\-/:]$').hasMatch(part)) {
      normalized.add(part);
      continue;
    }
    normalized.add(_normalizeCodeLikeSegment(part));
  }

  return _normalizeCompoundCodeSeparators(normalized.join());
}

/// Normalizes uppercase and digit-lookalike boundaries within a code segment.
String _normalizeCodeLikeSegment(String segment) {
  final String upper = segment.replaceAllMapped(RegExp(r'[A-Za-z]+'), (
    Match match,
  ) {
    return match.group(0)!.toUpperCase();
  });
  final bool digitDominant = _isDigitDominantCodeSegment(upper);

  final StringBuffer buffer = StringBuffer();
  int index = 0;
  while (index < upper.length) {
    final String ch = upper[index];
    final int code = upper.codeUnitAt(index);
    if (!isLetter(code) || !_codeDigitLookalikeMap.containsKey(ch)) {
      buffer.write(ch);
      index++;
      continue;
    }

    int end = index + 1;
    while (end < upper.length) {
      final String next = upper[end];
      final int nextCode = upper.codeUnitAt(end);
      if (!isLetter(nextCode) || !_codeDigitLookalikeMap.containsKey(next)) {
        break;
      }
      end++;
    }

    final bool nextDigit = end < upper.length && isDigit(upper.codeUnitAt(end));
    final bool prevDigit = index > 0 && isDigit(upper.codeUnitAt(index - 1));
    final bool shouldMap = digitDominant || (nextDigit && !prevDigit);
    if (shouldMap) {
      for (int i = index; i < end; i++) {
        buffer.write(_codeDigitLookalikeMap[upper[i]] ?? upper[i]);
      }
    } else {
      buffer.write(upper.substring(index, end));
    }

    index = end;
  }

  return buffer.toString();
}

/// Returns true when [segment] consists only of digits and digit-lookalikes.
bool _isDigitDominantCodeSegment(String segment) {
  int digits = 0;
  int mappableLetters = 0;
  int nonMappableLetters = 0;

  for (int i = 0; i < segment.length; i++) {
    final String ch = segment[i];
    final int code = segment.codeUnitAt(i);
    if (isDigit(code)) {
      digits++;
      continue;
    }
    if (!isLetter(code)) {
      continue;
    }
    if (_codeDigitLookalikeMap.containsKey(ch)) {
      mappableLetters++;
    } else {
      nonMappableLetters++;
    }
  }

  return digits > 0 && nonMappableLetters == 0 && digits >= mappableLetters;
}

/// Restores hyphen separators in simple three-part compound IDs.
String _normalizeCompoundCodeSeparators(String token) {
  if (!token.contains('+')) {
    return token;
  }

  final List<String> parts = token.split('+');
  if (parts.length != _compoundCodePartCount) {
    return token;
  }

  final String prefix = parts[_compoundCodePrefixPartIndex];
  final String middle = parts[_compoundCodeMiddlePartIndex];
  final String suffix = parts[_compoundCodeSuffixPartIndex];
  final bool prefixShape =
      prefix.length >= _compoundCodePrefixMinLength &&
      prefix.length <= _compoundCodePrefixMaxLength &&
      RegExp(r'^[A-Z]+$').hasMatch(prefix);
  final bool middleShape =
      middle.length >= _compoundCodeMiddleMinDigits &&
      RegExp(r'^\d+$').hasMatch(middle);
  final bool suffixShape =
      suffix.length >= _compoundCodeSuffixMinDigits &&
      RegExp(r'^\d+$').hasMatch(suffix);
  if (!prefixShape || !middleShape || !suffixShape) {
    return token;
  }

  return '$prefix-$middle-$suffix';
}

/// Repairs structured field labels using strict OCR-safe near-miss matching.
///
/// Labels like `Oate:` are often a single OCR confusion away from common field
/// words such as `Date:`. Only same-length, distance-1 dictionary matches that
/// differ by a known OCR confusion pair are accepted.
String _normalizeStructuredLabelToken(
  String token, {
  required bool applyDictionary,
}) {
  if (!applyDictionary) {
    return token.toLowerCase();
  }

  final String lower = token.toLowerCase();
  if (englishWords.contains(lower)) {
    return lower;
  }

  final String suggestion = findClosestWord(englishWords, lower);
  if (suggestion.length != token.length ||
      levenshteinDistance(lower, suggestion) != 1) {
    return lower;
  }

  int diffIndex = -1;
  for (int i = 0; i < token.length; i++) {
    if (lower[i] != suggestion[i].toLowerCase()) {
      diffIndex = i;
      break;
    }
  }
  if (diffIndex == -1 ||
      !isOcrConfusionPair(token[diffIndex], suggestion[diffIndex])) {
    return lower;
  }

  return suggestion;
}

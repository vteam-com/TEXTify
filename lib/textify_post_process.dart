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
const int _punctuationFilterShortLineMaxLength = 5;
const int _fragmentPairMinimumTokenCount = 2;
const int _fragmentPairShortWordLength = 3;
const int _fragmentPairLeftLengthWhenRightSingle = 6;
const int _nearMissMinTokenLength = 3;
const int _minMixedCaseTokenLength = 3;
const int _minAcronymTokenLength = 2;
const int _minWordLengthForNonConfusionSwap = 3;
const double _punctuationHeavyRatioThreshold = 0.4;
const int _nameLikeLineMinTokens = 2;
const int _nameLikeLineMaxTokens = 4;
const int _titleCasePreserveLowerTokenMaxLength = 2;
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
String postProcessText(String text, {bool applyDictionary = true}) {
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
    value = _normalizeDigitSegments(value);
    value = _normalizeFragmentedLine(value, applyDictionary: applyDictionary);
    if (applyDictionary) {
      value = _correctNearMissDictionaryWords(value);
    }
    processed.add(value);
  }

  final List<String> merged = _mergeNoiseLines(processed);
  final List<String> shortNoisyFixed = _normalizeShortNoisyLines(merged);
  final String joined = shortNoisyFixed.join('\n');
  final String normalized = _normalizePunctuationHeavyText(joined);
  final String lettersFixed = _normalizeLetterConfusions(normalized);
  return _normalizePunctuationSpacing(lettersFixed);
}

const int _uppercaseICodeUnit = 73;
const int _lowercaseLCodeUnit = 108;
const int _minWordLengthForILAmbiguity = 2;
const int _minWordLengthForCaseCoherence = 3;

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

    // If one case is strongly dominant, normalize the word
    if (total >= _minWordLengthForCaseCoherence) {
      if (upper >= total - 1 && upper > lower) {
        return word.toUpperCase();
      }
      if (lower >= total - 1 && lower > upper) {
        // Preserve Title Case
        if (_isUpper(word.codeUnitAt(0))) {
          return _sentenceCase(word.toLowerCase());
        }
        return word.toLowerCase();
      }
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

/// Repairs noisy separators and spacing in numeric expressions.
///
/// Handles cases like "1 . 23" -> "1.23" and detects digit-dominant lines
/// to remove all whitespace.
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
String _normalizeFragmentedLine(String line, {bool applyDictionary = true}) {
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

/// Normalizes tiny noisy lines often produced by decorative serif fragments.
List<String> _normalizeShortNoisyLines(List<String> lines) {
  return lines;
}

/// Returns true if the token is mixed-case (e.g., 'OpenAI').
bool _isMixedCase(String token) {
  if (token.length < _minMixedCaseTokenLength) return false;
  final String alpha = token.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (alpha.isEmpty) return false;

  bool hasUpper = false;
  bool hasLower = false;
  // Check if we have both upper and lower after the first character
  // (Title Case is handled separately by the dictionary)
  for (int i = 1; i < alpha.length; i++) {
    if (alpha[i] == alpha[i].toUpperCase()) hasUpper = true;
    if (alpha[i] == alpha[i].toLowerCase()) hasLower = true;
  }
  return hasUpper && hasLower;
}

/// Returns true if the token is likely an acronym (all caps).
bool _isAcronym(String token) {
  if (token.length < _minAcronymTokenLength) return false;
  final String alpha = token.replaceAll(RegExp(r'[^A-Za-z]'), '');
  return alpha.isNotEmpty && alpha == alpha.toUpperCase();
}

/// Returns true if the two characters are common OCR confusions (e.g., 'l' and 'I').
bool _isCommonOcrConfusion(String a, String b) {
  final String charA = a.toUpperCase();
  final String charB = b.toUpperCase();
  if (charA == charB) return true;

  const Map<String, Set<String>> confusionGroups = {
    'I': {'L', '1', '!', '|', 'T'},
    'L': {'I', '1', '!', '|'},
    '1': {'I', 'L', '!', '|'},
    'O': {'0', 'Q', 'D'},
    '0': {'O', 'Q', 'D'},
    'S': {'5', '8'},
    '5': {'S', '8'},
    '8': {'S', '5', 'B'},
    'B': {'8', 'D', '0'},
    'Z': {'2'},
    '2': {'Z'},
    'T': {'1', 'I', '7'},
    'G': {'6', '9'},
    '6': {'G'},
    '9': {'G'},
  };

  return confusionGroups[charA]?.contains(charB) ??
      confusionGroups[charB]?.contains(charA) ??
      false;
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
    if (_isAcronym(merged) || _isMixedCase(merged)) {
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
      tokens[i] = _isTitleCaseWord(merged)
          ? _toTitleCaseWord(suggestion)
          : suggestion;
      tokens.removeAt(i + 1);
      continue;
    }

    i++;
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

  // If it's a 2-word line starting with a TitleCase word followed by a common lowercase word,
  // it's likely a sentence rather than a name.
  if (tokens.length == _nameLikeLineMinTokens &&
      _isTitleCaseWord(tokens[0]) &&
      tokens[1] == tokens[1].toLowerCase() &&
      englishWords.contains(tokens[1])) {
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

    // Protect mixed-case words (e.g., 'OpenAI') and acronyms (e.g., 'GPT')
    // from being "corrected" to lowercase dictionary words.
    if (_isAcronym(token) || _isMixedCase(token)) {
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

      // If the swap is a known OCR confusion (l/I, O/0, etc.), we allow it.
      bool isCommonConfusion = _isCommonOcrConfusion(from, to);

      // If it is NOT a common confusion, we only allow it for long words
      // where we are very certain of the rest of the word.
      if (!isCommonConfusion &&
          token.length < _minWordLengthForNonConfusionSwap) {
        return token;
      }
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

/// Normalizes punctuation spacing errors common in OCR.
String _normalizePunctuationSpacing(String text) {
  // Fixes "word . next" -> "word. next"
  String result = text.replaceAllMapped(RegExp(r'\s+([.,!?;:])'), (match) {
    return match.group(_regexGroupFirst)!;
  });

  // Fixes "word.next" -> "word. next" but not "www.AMAZON" (domain-like).
  // Skip inserting a space when the punctuation is a dot preceded by a
  // letter AND followed by a letter (domain, URL, or abbreviation pattern).
  // Numbered lists like "1.Hello" still get a space since the dot follows a digit.
  result = result.replaceAllMapped(RegExp(r'([.,!?;:])([A-Za-z])'), (match) {
    final String punct = match.group(_regexGroupFirst)!;
    final String letter = match.group(_regexGroupSecond)!;
    if (punct == '.' && match.start > 0) {
      final int prevCode = result.codeUnitAt(match.start - 1);
      if (_isLetter(prevCode)) {
        return '$punct$letter';
      }
    }
    return '$punct $letter';
  });

  return result;
}

/// Normalizes common multi-character letter confusions.
String _normalizeLetterConfusions(String text) {
  return text
      .replaceAll('rn', 'm')
      .replaceAll('cl', 'd')
      .replaceAll('vv', 'w')
      .replaceAll('III', 'm');
}

/// Normalizes lines that are overwhelmingly punctuation.
String _normalizePunctuationHeavyText(String text) {
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
      if (_isLetter(code) || _isDigit(code)) {
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

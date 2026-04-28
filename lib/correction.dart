/// This library is part of the Textify package.
/// Provides text correction utilities for improving OCR results through dictionary matching
/// and character substitution algorithms.
library;

import 'dart:math';

import 'package:textify/char_utils.dart';
import 'package:textify/models/english_words.dart';
import 'package:textify/post_process_helpers.dart' show hasCodeLikeToken, shouldPreserveLongLowercaseProse;

const int _minSubstitutionPairsRequired = 2;

/// Minimum length for tokens to be considered for dictionary-based correction.
const int _minDictionaryTokenLength = 2;
const int _maxDictionaryFallbackDistance = 1;
const int _minFallbackCorrectionLength = 4;
const int _restoredAcronymMinLetters = 3;
const int _shortAcronymPhraseMaxWords = 4;
const int _longLowercaseSentenceMinTokens = 6;
const int _longLowercaseSentenceMinLetters = 24;
const int _structuredUpperValueMaxWords = 2;
const int _structuredUpperValueMaxLength = 3;

/// Divisor for title-case majority threshold: uppercaseStartCount must exceed
/// alphaWordCount divided by this value to be considered genuine title case.
const int _titleCaseMajorityDivisor = 2;

/// Returns true if [a] and [b] are characters commonly confused by OCR
/// based on visual similarity of glyph shapes.
bool isOcrConfusionPair(String a, String b) {
  final String upper1 = a.toUpperCase();
  final String upper2 = b.toUpperCase();
  if (upper1 == upper2) return true;

  // Symmetric lookup: visual-similarity groups for OCR template matching.
  const Map<String, Set<String>> confusionGroups = {
    'A': {'X', '@'},
    'I': {'L', '1', '!', '|', 'T'},
    'L': {'I', '1', '!', '|', 'B'},
    '1': {'I', 'L', '!', '|'},
    'O': {'0', 'Q', 'D', 'B'},
    '0': {'O', 'Q', 'D', 'B'},
    'S': {'5', '8'},
    '5': {'S', '8'},
    '8': {'S', '5', 'B'},
    'B': {'8', 'D', '0', 'O', 'L'},
    'Z': {'2'},
    '2': {'Z'},
    'T': {'1', 'I', '7', 'F'},
    'G': {'6', '9'},
    '6': {'G'},
    '9': {'G'},
    'N': {'M', 'H'},
    'M': {'N', 'H'},
    'H': {'N', 'M'},
    'U': {'L'},
    'X': {'A'},
    'E': {'O'},
    'F': {'P', 'T'},
    'P': {'F'},
  };

  return confusionGroups[upper1]?.contains(upper2) ??
      confusionGroups[upper2]?.contains(upper1) ??
      false;
}

/// Replaces [from] with [to] in [word], adjusting the case of [to] to match
/// the nearest alphabetic neighbor at each replacement site.
///
/// This prevents case contamination: "OpenAl".replace('l','i') returns
/// "OpenAI" (uppercase, matching neighbor 'A') instead of "OpenAi".
String _caseAwareReplace(String word, String from, String to) {
  final StringBuffer buf = StringBuffer();
  for (int i = 0; i < word.length; i++) {
    if (word[i] == from) {
      // Look at the nearest alphabetic neighbor to decide case.
      bool neighborIsUpper = false;
      // Check left neighbor first, then right.
      for (int d = i - 1; d >= 0; d--) {
        if (isUppercaseLetter(word[d])) {
          neighborIsUpper = true;
          break;
        }
        if (isLowercaseLetter(word[d])) {
          break;
        }
      }
      if (!neighborIsUpper) {
        for (int d = i + 1; d < word.length; d++) {
          if (isUppercaseLetter(word[d])) {
            neighborIsUpper = true;
            break;
          }
          if (isLowercaseLetter(word[d])) {
            break;
          }
        }
      }
      buf.write(neighborIsUpper ? to.toUpperCase() : to.toLowerCase());
    } else {
      buf.write(word[i]);
    }
  }
  return buf.toString();
}

/// Utility class to analyze character statistics in text.
///
/// This class counts the number of letters and digits in a given text,
/// which helps determine whether a string is primarily alphabetic or numeric.
/// Used by text correction functions to make appropriate character substitutions.
class CharacterStats {
  /// Construct and inspect the [text]
  CharacterStats([final String text = '']) {
    inspect(text);
  }

  /// The count of letter characters in the analyzed text.
  int letters = 0;

  /// The count of digit characters in the analyzed text.
  int digits = 0;

  /// The count of space characters in the analyzed text.
  int spaces = 0;

  /// The count of upper case characters in the analyzed text.
  /// Non-letters (excluding spaces) are counted toward this total for casing heuristics.
  int uppercase = 0;

  /// The count of lower case characters in the analyzed text.
  int lowercase = 0;

  /// The count of punctuation/symbol characters in the analyzed text.
  int punctuation = 0;

  /// Clear the counters tracked by [inspect].
  void reset() {
    letters = 0;
    digits = 0;
    spaces = 0;
    uppercase = 0;
    lowercase = 0;
    punctuation = 0;
  }

  /// Analyzes the [text] and updates letter and digit counts.
  ///
  /// Iterates through each character in the input text and
  /// increments the appropriate counter based on character type.
  void inspect(final String text) {
    reset();

    for (final char in text.split('')) {
      if (char == ' ') {
        spaces++;
      } else if (isLetter(char)) {
        letters++;
        if (isUpperCase(char)) {
          uppercase++;
        } else {
          lowercase++;
        }
      } else if (isDigit(char)) {
        digits++;
        uppercase++;
      } else {
        punctuation++;
        uppercase++;
      }
    }
  }

  /// Returns true if the token is primarily punctuation/symbols.
  bool mostlyPunctuation() {
    final int total = letters + digits + punctuation;
    if (total == 0) return false;
    return punctuation > (letters + digits);
  }

  /// Returns true if the analyzed text contains more digits than letters.
  ///
  /// This method helps determine whether a string should be treated as
  /// primarily numeric for correction purposes.
  bool mostlyDigits() {
    return digits > letters;
  }

  static const double _mostlyUppercaseThreshold = 0.9;

  /// Returns true if the analyzed text is overwhelmingly uppercase (90%+).
  bool mostlyUppercase() {
    if (letters == 0) return false;
    return (uppercase / letters) >= _mostlyUppercaseThreshold;
  }
}

/// Applies dictionary-based correction to the extracted text.
///
/// This function improves recognition accuracy by comparing extracted text
/// against a dictionary and correcting likely missed recognitions.
///
/// [inputParagraph] is the raw text extracted from the image, which may contain multiple lines.
/// Returns the corrected text after dictionary-based processing.
String applyCorrection(
  final String inputParagraph,
  final bool applyDictionary,
) {
  /// Map of commonly confused characters and their possible substitutions.
  /// Keys are characters that might be incorrectly recognized, and values are lists
  /// of possible correct characters to try as replacements.
  const Map<String, List<String>> correctionLetters = {
    '0': ['O', 'o', 'B', '8'],
    '5': ['S', 's'],
    'l': ['i', 'I', 'L', '1', '!'],
    'i': ['l', 'I', '1', '!'],
    'I': ['l', 'i', '1', '!'],
    'S': ['5'],
    'o': ['D', '0', 'e'],
    'O': ['D', '0'],
    'e': ['o'],
    '!': ['T', 'I', 'i', 'l', '1'],
    '@': ['A', 'a'],
  };
  final linesOfText = inputParagraph.split('\n');
  final List<String> correctedBlob = [];

  for (final String sentence in linesOfText) {
    String correctedSentence = sentenceFixZeroAnO(sentence);

    if (applyDictionary) {
      correctedBlob.add(
        applyDictionaryCorrectionOnSingleSentence(
          correctedSentence,
          correctionLetters,
        ),
      );
    } else {
      correctedBlob.add(correctedSentence);
    }
  }
  return correctedBlob.join('\n');
}

/// Applies dictionary-based correction to [inputSentence]. It first tries to match words
/// directly in the dictionary, then attempts to substitute commonly confused characters [correctionLetters],
/// and finally finds the closest match in the dictionary if no direct match is found.
/// The original casing of the input words is preserved in the corrected output.
String applyDictionaryCorrectionOnSingleSentence(
  final String inputSentence,
  final Map<String, List<String>> correctionLetters,
) {
  final regex = RegExp(
    r'(\s+|[.,!?;:])',
  ); // Matches spaces or single punctuation marks

  final words = inputSentence
      .splitMapJoin(
        regex,
        onMatch: (m) => '¤${m[0]}¤', // Tag matched pieces
        onNonMatch: (n) => '¤$n¤', // Tag non-matched parts (i.e., words)
      )
      .split('¤')
      .where((s) => s.isNotEmpty)
      .toList();

  for (int i = 0; i < words.length; i++) {
    String word = words[i];
    if (word.length >= _minDictionaryTokenLength &&
        !['.', ',', '!', '?', ';', ':', ' '].contains(word)) {
      final stats = CharacterStats(word);
      // No need to process numbers or symbol-heavy tokens
      if (!stats.mostlyDigits() && !stats.mostlyPunctuation()) {
        //
        // Try direct dictionary match first
        //
        if (!englishWords.contains(word.toLowerCase())) {
          //
          // Try substituting commonly confused characters.
          // First try single substitution types, then try pairs
          // for words with multiple confusion types (e.g. o→e + l→i).
          //
          String modifiedWord = word;
          bool foundMatch = false;

          // Collect all valid single-substitution variants.
          final List<MapEntry<String, String>> singleSubs = [];
          for (final MapEntry<String, List<String>> entry
              in correctionLetters.entries) {
            if (modifiedWord.contains(entry.key)) {
              for (final String substitute in entry.value) {
                final String testWord = _caseAwareReplace(
                  modifiedWord,
                  entry.key,
                  substitute,
                );

                if (testWord != modifiedWord) {
                  if (englishWords.contains(testWord.toLowerCase())) {
                    modifiedWord = testWord;
                    foundMatch = true;
                    break;
                  }
                  singleSubs.add(MapEntry(entry.key, substitute));
                }
              }
              if (foundMatch) {
                break;
              }
            }
          }

          // Pass 2: try chaining pairs of substitutions.
          // For multi-substitution corrections, use lowercase matching
          // and apply the original word's dominant casing to the result,
          // since neighbor-based casing from noisy OCR is unreliable
          // when multiple characters are wrong.
          if (!foundMatch &&
              singleSubs.length >= _minSubstitutionPairsRequired) {
            for (int a = 0; a < singleSubs.length && !foundMatch; a++) {
              final String after1 = _caseAwareReplace(
                word,
                singleSubs[a].key,
                singleSubs[a].value,
              );
              for (int b = a + 1; b < singleSubs.length; b++) {
                if (!after1.contains(singleSubs[b].key)) continue;
                final String after2 = _caseAwareReplace(
                  after1,
                  singleSubs[b].key,
                  singleSubs[b].value,
                );
                if (englishWords.contains(after2.toLowerCase())) {
                  // Use lowercase form — let casing normalization handle it.
                  modifiedWord = after2.toLowerCase();
                  foundMatch = true;
                  break;
                }
              }
            }
          }

          if (!foundMatch && word.length >= _minFallbackCorrectionLength) {
            // If no direct match after substitutions, find a conservative
            // same-length near match to avoid over-correcting tokens.
            // Only for words long enough that a single-character edit is
            // proportionally small (≥4 chars = ≤25% change).
            final String suggestion = findClosestMatchingWordInDictionary(word);
            final int distance = levenshteinDistance(
              word.toLowerCase(),
              suggestion.toLowerCase(),
            );
            if (suggestion.length == word.length &&
                distance <= _maxDictionaryFallbackDistance) {
              // Only accept when every changed character is a plausible
              // OCR confusion (e.g., l↔I, 0↔O). This prevents
              // morphological form changes like "Released" → "Releases"
              // where d→s is not an OCR confusion.
              bool acceptFallback = true;
              for (int ci = 0; ci < word.length; ci++) {
                if (word[ci].toLowerCase() != suggestion[ci].toLowerCase()) {
                  if (!isOcrConfusionPair(word[ci], suggestion[ci])) {
                    acceptFallback = false;
                    break;
                  }
                }
              }
              if (acceptFallback) {
                modifiedWord = suggestion;
              }
            }
          }

          words[i] = modifiedWord;
        }
      }
    }
  }

  return normalizeCasingOfParagraph(words.join(''));
}

/// Finds the closest matching word in the dictionary for a given word.
///
/// This function takes a [word] string to find a match for and uses
/// the Levenshtein distance to find the closest word in the dictionary.
/// It also handles special cases for plural words ending with 's' or 'S'.
///
/// Returns the closest matching word with the original casing preserved for unchanged letters.
String findClosestMatchingWordInDictionary(String word) {
  final String lowerWord = word.toLowerCase();
  String suggestion =
      _findClosestSameLengthWordInDictionary(lowerWord) ??
      findClosestWord(englishWords, lowerWord);
  String lastChar = word[word.length - 1];
  if ((lastChar == 's' || lastChar == 'S') &&
      word.length - 1 == suggestion.length) {
    suggestion += lastChar;
  }
  // Preserve original casing for unchanged letters
  if (word.length == suggestion.length) {
    String result = '';
    for (int i = 0; i < word.length; i++) {
      if (word[i].toLowerCase() == suggestion[i].toLowerCase()) {
        result += word[i]; // Keep original casing
      } else {
        result += suggestion[i]; // Use suggestion's character
      }
    }
    word = result;
  } else {
    word = suggestion;
  }
  return word;
}

/// Finds the nearest dictionary word with the same length as [word].
///
/// This narrows OCR fallback selection to candidates that preserve token width,
/// then breaks ties by favoring candidates whose differing characters align
/// with known OCR confusion pairs.
String? _findClosestSameLengthWordInDictionary(String word) {
  String? bestMatch;
  int? bestDistance;
  int bestConfusionScore = -1;

  for (final String dictWord in englishWords) {
    if (dictWord.length != word.length) {
      continue;
    }

    final String lowerDictWord = dictWord.toLowerCase();
    final int distance = levenshteinDistance(word, lowerDictWord);
    final int confusionScore = _sameLengthOcrConfusionScore(
      word,
      lowerDictWord,
    );

    final bool isBetterMatch =
        bestDistance == null ||
        distance < bestDistance ||
        (distance == bestDistance && confusionScore > bestConfusionScore) ||
        (distance == bestDistance &&
            confusionScore == bestConfusionScore &&
            bestMatch != null &&
            lowerDictWord.compareTo(bestMatch) < 0);

    if (isBetterMatch) {
      bestMatch = lowerDictWord;
      bestDistance = distance;
      bestConfusionScore = confusionScore;
    }
  }

  return bestMatch;
}

/// Counts same-position character differences that are valid OCR confusions.
///
/// Higher scores indicate that [candidate] differs from [source] in ways that
/// are more plausibly explained by OCR glyph substitution rather than a real
/// lexical change.
int _sameLengthOcrConfusionScore(String source, String candidate) {
  int score = 0;
  for (int i = 0; i < source.length; i++) {
    if (source[i] == candidate[i]) {
      continue;
    }
    if (isOcrConfusionPair(source[i], candidate[i])) {
      score++;
    }
  }
  return score;
}

/// Processes text to correct common OCR errors, focusing on zero/letter 'O' confusion.
///
/// This function analyzes each word in the input text to determine whether characters
/// should be interpreted as digits or letters based on context. It specifically handles
/// the common OCR confusion between the digit '0' and the letter 'O'.
///
/// The function applies two main corrections:
/// 1. For words that appear to be mostly numeric, it converts letter-like characters to digits
/// 2. For words that appear to be mostly alphabetic, it converts '0' characters to the letter 'O'
///
/// [inputSentence] is the text string to be processed.
/// Returns the corrected text with appropriate character substitutions and normalized casing.
String sentenceFixZeroAnO(final String inputSentence) {
  // Split the input into individual words for processing
  List<String> words = inputSentence.split(' ');

  for (int i = 0; i < words.length; i++) {
    // Remove any newline characters that might be present
    String word = words[i].replaceAll('\n', '');
    if (word.isNotEmpty) {
      // Split on non-alphanumeric boundaries so that mixed tokens like
      // "ORD+20250615" are analyzed segment by segment.  This prevents
      // a mostly-digit suffix from forcing letter→digit conversion on
      // an alphabetic prefix.
      words[i] = word.splitMapJoin(
        RegExp(r'[A-Za-z0-9]+'),
        onMatch: (Match m) {
          final String segment = m.group(0)!;
          final CharacterStats stats = CharacterStats()..inspect(segment);
          if (stats.mostlyDigits()) {
            return digitCorrection(segment);
          }
          return replaceBadDigitsKeepCasing(segment);
        },
        onNonMatch: (String sep) => sep,
      );
    }
  }

  // Rejoin the corrected words into a sentence
  return words.join(' ');
}

/// Replaces zeros with the letter 'O' in words that are mostly letters.
///
/// This function examines [word] strings and replaces any '0' characters
/// with 'O' (uppercase) or 'o' (lowercase) based on the casing of surrounding characters.
/// It only makes this replacement if the word is primarily composed of letters rather than digits.
///
/// [word] is the potentially corrected word.
/// Returns the word with zeros replaced by appropriate letter 'O' if applicable.
String replaceBadDigitsKeepCasing(final String word) {
  // If no zeros in the string, return as is
  if (!word.contains('0')) {
    return word;
  }

  // Count uppercase and lowercase letters to determine dominant case
  int uppercaseCount = 0;
  int lowercaseCount = 0;

  for (final String char in word.split('')) {
    if (isLetter(char)) {
      if (isUpperCase(char)) {
        uppercaseCount++;
      } else {
        lowercaseCount++;
      }
    }
  }

  // Determine which case to use for 'O' replacement
  final String replacement = (uppercaseCount > lowercaseCount) ? 'O' : 'o';

  // Replace all zeros with the appropriate case of 'O'
  return word.replaceAll('0', replacement);
}

/// This function replaces problematic characters in the [input] string with their digit representations,
/// but only if the single text is mostly composed of digits.
String digitCorrection(final String input) {
  const Map<String, String> map = {
    'o': '0',
    'O': '0',
    'i': '1',
    'l': '1',
    's': '5',
    'S': '5',
    'B': '8',
  };

  // Otherwise, perform the digit replacement
  String correction = '';
  for (int i = 0; i < input.length; i++) {
    String char = input[i];
    if (isDigit(char)) {
      correction += char;
    } else {
      // Replace problematic characters with their digit representations
      correction += map[char] ?? char;
    }
  }
  return correction;
}

/// Finds the closest matching word in a [dictionary] for a given input [word].
///
/// This function takes a set of dictionary words and an input word, and returns the
/// closest matching word from the dictionary based on the Levenshtein distance.
/// It examines all words in the dictionary and returns the one with the minimum
/// Levenshtein distance. If multiple words have the same minimum distance, it returns
/// the longest one among them.
String findClosestWord(final Set<String> dictionary, final String word) {
  String closestMatch = dictionary.first; // Start with any word from dictionary
  int minDistance = levenshteinDistance(word, closestMatch.toLowerCase());

  for (String dictWord in dictionary) {
    int distance = levenshteinDistance(word, dictWord.toLowerCase());
    if (distance < minDistance ||
        (distance == minDistance && dictWord.length > closestMatch.length)) {
      minDistance = distance;
      closestMatch = dictWord;
    }
  }

  return closestMatch;
}

/// Calculates the Levenshtein distance between two strings.
///
/// The Levenshtein distance is a metric that measures the difference between two
/// strings. It is the minimum number of single-character edits (insertions,
/// deletions or substitutions) required to change one string into the other.
///
/// This function takes two strings [s1] and [s2] and returns the Levenshtein
/// distance between them.
int levenshteinDistance(final String s1, final String s2) {
  if (s1 == s2) {
    return 0;
  }
  if (s1.isEmpty) {
    return s2.length;
  }
  if (s2.isEmpty) {
    return s1.length;
  }

  List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
  List<int> v1 = List<int>.filled(s2.length + 1, 0);

  for (int i = 0; i < s1.length; i++) {
    v1[0] = i + 1;

    for (int j = 0; j < s2.length; j++) {
      int cost = (s1[i] == s2[j]) ? 0 : 1;
      v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
    }

    for (int j = 0; j < v0.length; j++) {
      v0[j] = v1[j];
    }
  }

  return v1[s2.length];
}

bool _isRestorableSentenceAcronym(String word) {
  final String alpha = word.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (alpha.isEmpty || alpha != alpha.toUpperCase()) {
    return false;
  }

  return alpha.length >= _restoredAcronymMinLetters ||
      !englishWords.contains(alpha.toLowerCase());
}

/// Returns true for structured `Label: VALUE` lines with short uppercase values.
///
/// This identifies status-like or field/value rows such as `Status: OK` so
/// sentence-level casing normalization can preserve the uppercase value.
bool _hasStructuredShortUppercaseFieldValue(String sentence) {
  final Match? match = RegExp(
    r'^\s*[A-Za-z]+(?:\s+[A-Za-z]+){0,2}\s*:\s*([A-Z]{2,}(?:\s+[A-Z]{2,}){0,1})\s*$',
  ).firstMatch(sentence);
  if (match == null) {
    return false;
  }

  final String rawValue = match.group(1) ?? '';
  if (rawValue.isEmpty) {
    return false;
  }

  final List<String> tokens = rawValue
      .split(RegExp(r'\s+'))
      .where((String token) => token.isNotEmpty)
      .toList();
  if (tokens.isEmpty || tokens.length > _structuredUpperValueMaxWords) {
    return false;
  }

  return tokens.every(
    (String token) =>
        token.length >= _minDictionaryTokenLength &&
        token.length <= _structuredUpperValueMaxLength,
  );
}

String _capitalizeVeryShortLowercaseWords(String sentence) {
  return sentence.replaceAllMapped(RegExp(r'\b([a-z]{1,2})\b'), (Match m) {
    final String word = m.group(1)!;
    return word[0].toUpperCase() + word.substring(1);
  });
}

/// Processes a sentence and applies appropriate casing rules.
///
/// This function takes a sentence string and ensures the first letter is capitalized.
/// Returns the processed sentence with normalized casing.
String normalizeCasingOfSentence(final String sentence) {
  if (sentence.isEmpty) {
    return sentence;
  }

  // Preserve codes and IDs, but keep normal prose lines with dates/numbers
  // eligible for sentence-level case cleanup.
  if (hasCodeLikeToken(sentence) ||
      _hasStructuredShortUppercaseFieldValue(sentence)) {
    return sentence;
  }

  // Count letters to determine dominant case
  int upper = 0;
  int lower = 0;
  for (int i = 0; i < sentence.length; i++) {
    final String char = sentence[i];
    if (isUppercaseLetter(char)) {
      upper++;
    } else if (isLowercaseLetter(char)) {
      lower++;
    }
  }

  // If the sentence is mostly uppercase, preserve it (e.g., "HELLO WORLD")
  if (upper > lower && upper > 1) {
    return sentence;
  }

  // If multiple words start with an uppercase letter and each capitalized word
  // has clean casing (first letter upper, remaining letters lower or non-letter),
  // the sentence likely uses title case, proper nouns, or acronyms.
  // Preserve the original casing instead of blanket-lowercasing.
  // Words with noisy internal uppercase like "CaSe" disqualify the sentence.
  const int noisyCasingTransitionThreshold = 2;
  final List<String> words = sentence.trim().split(RegExp(r'\s+'));
  int titleCaseTokenCount = 0;
  int acronymTokenCount = 0;
  int alphaWordCount = 0;
  bool hasNoisyCasing = false;
  for (final String word in words) {
    if (word.isEmpty || !isLetter(word[0])) continue;
    alphaWordCount++;
    if (isUppercaseLetter(word[0])) {
      // Skip words containing digits — these are likely codes or dates
      // with OCR-confused leading letters (e.g., "O3/15/2025"), not
      // genuine title-case words.
      bool hasDigit = false;
      for (int ci = 0; ci < word.length; ci++) {
        if (isDigit(word[ci])) {
          hasDigit = true;
          break;
        }
      }
      if (hasDigit) continue;

      final String alphaOnly = word.replaceAll(RegExp(r'[^A-Za-z]'), '');
      if (alphaOnly.isNotEmpty && alphaOnly == alphaOnly.toUpperCase()) {
        if (_isRestorableSentenceAcronym(word)) {
          acronymTokenCount++;
        }
        continue;
      }

      titleCaseTokenCount++;
      // Detect noisy internal casing by counting case transitions in the tail.
      // "CaSe" tail: L,U,L → 2 transitions → noisy OCR artifact.
      // "OpenAI" tail: L,L,L,U,U → 1 transition → valid camelCase/brand.
      // "Released" tail: all lower → 0 transitions → clean title case.
      int transitions = 0;
      bool? lastWasUpper;
      for (int ci = 1; ci < word.length; ci++) {
        if (isUppercaseLetter(word[ci])) {
          if (lastWasUpper == false) transitions++;
          lastWasUpper = true;
        } else if (isLowercaseLetter(word[ci])) {
          if (lastWasUpper == true) transitions++;
          lastWasUpper = false;
        }
      }
      if (transitions >= noisyCasingTransitionThreshold) {
        hasNoisyCasing = true;
      }
    }
  }
  // Only treat as title-case when the majority of alphabetic words start
  // uppercase.  A stray OCR capitalization (e.g., "With" for "with") should
  // not trigger short-word capitalization across the whole sentence.
  final bool isTitleCase =
      titleCaseTokenCount > 1 &&
      !hasNoisyCasing &&
      alphaWordCount > 0 &&
      titleCaseTokenCount > alphaWordCount ~/ _titleCaseMajorityDivisor;
  if (isTitleCase) {
    // In title-case sentences, capitalize very short (1-2 char) lowercase
    // words to match the dominant pattern.  These often arise from OCR
    // confusion between 'l' and 'I' producing "in" instead of "In".
    return _capitalizeVeryShortLowercaseWords(sentence);
  }

  // Preserve sentences with multiple uppercase-starting words even when
  // the strict title-case threshold is not met (e.g., one stray OCR
  // capitalization among many lowercase words).
  if (!hasNoisyCasing &&
      (titleCaseTokenCount > 1 ||
          (titleCaseTokenCount == 1 &&
              acronymTokenCount == 1 &&
              alphaWordCount <= _shortAcronymPhraseMaxWords))) {
    if (titleCaseTokenCount > 1 && acronymTokenCount > 0) {
      return _capitalizeVeryShortLowercaseWords(sentence);
    }
    return sentence;
  }

  final String trimmed = sentence.trimLeft();
  if (trimmed.isEmpty) {
    return sentence;
  }

  final int offset = sentence.length - trimmed.length;
  if (shouldPreserveLongLowercaseProse(
    trimmed,
    minTokens: _longLowercaseSentenceMinTokens,
    minLetters: _longLowercaseSentenceMinLetters,
  )) {
    return sentence.substring(0, offset) + trimmed.toLowerCase();
  }

  String content = trimmed.toLowerCase();
  final String firstChar = content[0];

  if (isLetter(firstChar)) {
    content = firstChar.toUpperCase() + content.substring(1);
  }

  final StringBuffer restoredAcronyms = StringBuffer();
  int restoreIndex = 0;
  for (final Match match in RegExp(r'[A-Za-z][A-Za-z.]*').allMatches(trimmed)) {
    restoredAcronyms.write(content.substring(restoreIndex, match.start));
    final String originalToken = match.group(0)!;
    if (_isRestorableSentenceAcronym(originalToken)) {
      restoredAcronyms.write(originalToken);
    } else {
      restoredAcronyms.write(content.substring(match.start, match.end));
    }
    restoreIndex = match.end;
  }
  restoredAcronyms.write(content.substring(restoreIndex));
  content = restoredAcronyms.toString();

  // Restore standalone single uppercase letters from the original text.
  // Words like "A" (article) and "I" (pronoun) should preserve their
  // uppercase form even in predominantly lowercase sentences.
  for (int i = 0; i < content.length && i < trimmed.length; i++) {
    if (isUppercaseLetter(trimmed[i])) {
      final bool atStart = i == 0 || !isLetter(trimmed[i - 1]);
      final bool atEnd = i == trimmed.length - 1 || !isLetter(trimmed[i + 1]);
      if (atStart && atEnd) {
        content =
            content.substring(0, i) + trimmed[i] + content.substring(i + 1);
      }
    }
  }

  return sentence.substring(0, offset) + content;
}

/// Normalizes the casing of the input string by processing each sentence.
///
/// This function takes a [String] [input] and returns a new string with the casing
/// normalized. It processes the input by breaking it into sentences, and then
/// applies casing rules to each sentence.
///
/// The function handles various sentence-ending characters (`.`, `!`, `?`, `\n`)
/// and preserves any non-letter characters in the input.
String normalizeCasingOfParagraph(final String input) {
  if (input.isEmpty) {
    return input;
  }

  // Define sentence-ending characters
  const List<String> sentenceEndings = ['.', '!', '?', '\n'];

  StringBuffer result = StringBuffer();
  StringBuffer currentSentence = StringBuffer();

  for (int i = 0; i < input.length; i++) {
    String char = input[i];
    currentSentence.write(char);

    // If the character is a sentence-ending character, process the sentence
    if (sentenceEndings.contains(char)) {
      result.write(normalizeCasingOfSentence(currentSentence.toString()));
      currentSentence.clear();
    }
  }

  // Process any remaining sentence
  if (currentSentence.isNotEmpty) {
    result.write(normalizeCasingOfSentence(currentSentence.toString()));
  }

  return result.toString();
}

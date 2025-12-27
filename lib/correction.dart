/// This library is part of the Textify package.
/// Provides text correction utilities for improving OCR results through dictionary matching
/// and character substitution algorithms.
library;

import 'dart:math';
import 'package:textify/models/english_words.dart';

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
  /// Digits are considered uppercase
  int uppercase = 0;

  /// The count of lower case characters in the analyzed text.
  int lowercase = 0;

  /// Clear the counters
  void reset() {
    letters = 0;
    digits = 0;
    spaces = 0;
  }

  /// Analyzes the [text] and updates letter and digit counts.
  ///
  /// Iterates through each character in the input text and
  /// increments the appropriate counter based on character type.
  void inspect(final String text) {
    reset();

    for (final char in text.split('')) {
      if (isLetter(char)) {
        letters++;
        if (isUpperCase(char)) {
          uppercase++;
        } else {
          lowercase++;
        }
      } else {
        uppercase++;
        if (isDigit(char)) {
          digits++;
        }
      }
    }
  }

  /// Returns true if the analyzed text contains more digits than letters.
  ///
  /// This method helps determine whether a string should be treated as
  /// primarily numeric for correction purposes.
  bool mostlyDigits() {
    return digits > letters;
  }

  /// Returns true if the analyzed text contains more uppercase than lowercase letters.
  ///
  /// This method helps determine whether a string should be treated as
  /// primarily uppercase for casing normalization purposes.
  bool mostlyUppercase() {
    return letters > 0 && uppercase > lowercase;
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
    'l': ['L', '1', 'i', '!'],
    'S': ['5'],
    'o': ['D', '0'],
    'O': ['D', '0'],
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
    if (word.length > 1 &&
        !['.', ',', '!', '?', ';', ':', ' '].contains(word)) {
      // No need to process numbers
      if (!CharacterStats(word).mostlyDigits()) {
        //
        // Try direct dictionary match first
        //
        if (!englishWords.contains(word.toLowerCase())) {
          //
          // Try substituting commonly confused characters
          //
          String modifiedWord = word;
          bool foundMatch = false;

          for (final MapEntry<String, List<String>> entry
              in correctionLetters.entries) {
            if (word.contains(entry.key)) {
              for (final String substitute in entry.value) {
                final String testWord = word.replaceAll(entry.key, substitute);

                if (englishWords.contains(testWord.toLowerCase())) {
                  modifiedWord = testWord;
                  foundMatch = true;
                  break;
                }
              }
              if (foundMatch) {
                break;
              }
            }
          }

          if (!foundMatch) {
            // If no direct match after substitutions, find closest match
            modifiedWord = findClosestMatchingWordInDictionary(word);
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
  String suggestion = findClosestWord(englishWords, word.toLowerCase());
  String lastChar = word[word.length - 1];
  if (lastChar == 's' ||
      lastChar == 'S' && (word.length - 1 == suggestion.length)) {
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
      CharacterStats stats = CharacterStats();
      stats.inspect(word);

      if (stats.mostlyDigits()) {
        words[i] = digitCorrection(word);
      } else {
        // For words that are primarily alphabetic, convert any '0' characters to 'O'/'o'
        word = replaceBadDigitsKeepCasing(word);
        words[i] = word;
      }
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

/// Processes a sentence and applies appropriate casing rules.
///
/// This function takes a sentence string and applies the following rules:
/// - If most letters are uppercase, converts the entire sentence to uppercase
/// - Otherwise, capitalizes the first letter and converts the rest to lowercase
///
/// Returns the processed sentence with normalized casing.
String normalizeCasingOfSentence(final String sentence) {
  if (sentence.isEmpty) {
    return sentence;
  }

  StringBuffer result = StringBuffer();
  CharacterStats stats = CharacterStats(sentence);

  // If most letters in the sentence are uppercase, convert the whole sentence to uppercase
  if (stats.mostlyUppercase()) {
    return sentence.toUpperCase();
  } else {
    // Find the first letter in the sentence to capitalize
    int firstLetterIndex = sentence
        .split('')
        .indexWhere((char) => isLetter(char));

    if (firstLetterIndex != -1) {
      // Capitalize the first letter and lowercase the rest
      result.write(sentence.substring(0, firstLetterIndex));
      result.write(sentence[firstLetterIndex].toUpperCase());
      result.write(sentence.substring(firstLetterIndex + 1).toLowerCase());
    } else {
      // No letters found, just append the sentence
      result.write(sentence);
    }
  }

  return result.toString();
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

/// Checks whether the given string is all uppercase.
///
/// This function takes a [String] [str] and returns `true` if the string contains only
/// uppercase characters, and `false` otherwise.
bool isUpperCase(final String str) {
  return str == str.toUpperCase();
}

/// Checks whether the given string is a digit from 0 to 9.
///
/// This function takes a [String] and returns `true` if the string represents a
/// digit from 0 to 9, and `false` otherwise.
bool isDigit(final String char) {
  const List<String> digits = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
  ];
  return digits.contains(char);
}

/// Checks whether the given character is a letter.
///
/// This function takes a [String] representing a single [character] and returns
/// `true` if the character is a letter (uppercase or lowercase), and `false`
/// otherwise.
bool isLetter(final String character) {
  // use this trick to see if the character can have different casing
  return character.toLowerCase() != character.toUpperCase();
}

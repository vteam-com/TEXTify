import 'dart:math';
import 'package:textify/english_words.dart';

/// Applies dictionary-based correction to the extracted text.
///
/// This function improves recognition accuracy by comparing extracted text
/// against a dictionary and correcting likely missed recognitions.
///
/// [inputParagraph] is the raw text extracted from the image, which may contain multiple lines.
/// Returns the corrected text after dictionary-based processing.
String applyDictionaryCorrection(
  final String inputParagraph,
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

  for (final line in linesOfText) {
    correctedBlob.add(
      applyDictionaryCorrectionOnSingleSentence(line, correctionLetters),
    );
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
  String cleanedUpText = inputSentence;
  List<String> words = inputSentence.split(' ');

  for (int i = 0; i < words.length; i++) {
    String word = words[i].replaceAll('\n', '');
    if (word.isEmpty) {
      continue;
    }

    final String allDigits = digitCorrection(word);
    if (allDigits.isNotEmpty) {
      words[i] = allDigits;
      continue;
    }

    // Try direct dictionary match first
    if (englishWords.contains(word.toLowerCase())) {
      words[i] = applyCasingToDifferingChars(word, word.toLowerCase());
      continue;
    }

    // Try substituting commonly confused characters
    String modifiedWord = word;
    bool foundMatch = false;

    for (final MapEntry<String, List<String>> entry
        in correctionLetters.entries) {
      for (final String substitute in entry.value) {
        if (word.contains(entry.key)) {
          String testWord = word.replaceAll(entry.key, substitute);

          if (englishWords.contains(testWord.toLowerCase())) {
            modifiedWord = testWord;
            foundMatch = true;
            break;
          }
        }
      }
      if (foundMatch) {
        break;
      }
    }

    // If no direct match after substitutions, find closest match
    if (!foundMatch) {
      String? suggestion =
          findClosestWord(englishWords, modifiedWord.toLowerCase());
      if (suggestion == null) {
        // If the last letter is an 's' or 'S', remove it and try again to see if there's a hit on the singular version of the word
        String lastChar = modifiedWord[modifiedWord.length - 1];
        if (lastChar == 's' || lastChar == 'S') {
          String withoutLastLetter =
              modifiedWord.substring(0, modifiedWord.length - 1);
          suggestion = findClosestWord(
            englishWords,
            withoutLastLetter.toLowerCase(),
          );
          if (suggestion != null) {
            suggestion += lastChar;
          }
        }
      } else {
        String lastChar = modifiedWord[modifiedWord.length - 1];
        if (lastChar == 's' ||
            lastChar == 'S' && (modifiedWord.length - 1 == suggestion.length)) {
          suggestion += lastChar;
        }
        if (modifiedWord.length == suggestion.length) {
          modifiedWord = suggestion;
        }
      }
    }

    words[i] = applyCasingToDifferingChars(word, modifiedWord);
  }

  cleanedUpText = words.join(' ');
  return normalizeCasing(cleanedUpText);
}

/// This function replaces problematic characters in the [input] string with their digit representations,
/// but only if the word is mostly composed of digits.
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

  // Calculate the proportion of digits in the input string
  final int digitCount = input.split('').where((char) => isDigit(char)).length;
  double digitProportion = digitCount / input.length;

  // Apply the correction only if the string is mostly composed of digits (e.g., > 50%)
  if (digitProportion <= 0.5) {
    return ''; // If not mostly digits, return the input as is
  }

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
  return correction == input ? '' : correction;
}

/// Finds the closest matching word in a [dictionary] for a given input [word].
///
/// This function takes a set of dictionary words and an input word, and returns the
/// closest matching word from the dictionary based on the Levenshtein distance.
/// It only considers dictionary words that are of similar length (±1 character) to
/// the input word, and returns the dictionary word with the minimum Levenshtein
/// distance, or the longest word with the same minimum distance if there are
/// multiple candidates.
String? findClosestWord(
  final Set<String> dictionary,
  final String word,
) {
  String? closestMatch;
  int minDistance = 3; // Max edit distance to consider

  for (String dictWord in dictionary) {
    // Only consider words of similar length (±1 character)
    if ((dictWord.length - word.length).abs() <= 1) {
      int distance = levenshteinDistance(word, dictWord.toLowerCase());
      if (distance < minDistance ||
          (distance == minDistance &&
              dictWord.length > (closestMatch?.length ?? 0))) {
        minDistance = distance;
        closestMatch = dictWord;
      }
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

/// Applies the casing of the original string to the corrected string, preserving the casing of unchanged characters.
///
/// This function takes two strings, [original] and [corrected], and returns a new string where the casing of the `corrected` string
/// is modified to match the casing of the `original` string, except for characters that have been changed. The first modified character
/// is always uppercase, and subsequent modified characters match the casing of the following character in the `original` string, unless
/// the modified character is the last one, in which case it matches the casing of the previous character in the `original` string.
String applyCasingToDifferingChars(
  final String original,
  final String corrected,
) {
  if (original.length != corrected.length) {
    return corrected;
  }

  if (original == corrected) {
    return corrected;
  }

  StringBuffer result = StringBuffer();

  for (int i = 0; i < corrected.length; i++) {
    if (original[i].toLowerCase() != corrected[i].toLowerCase()) {
      if (i == 0) {
        // First modified character is always uppercase
        result.write(corrected[i].toUpperCase());
      } else if (i + 1 < original.length && isUpperCase(original[i + 1])) {
        // If the following character in the original string is uppercase
        result.write(corrected[i].toUpperCase());
      } else if (i == corrected.length - 1) {
        // Last modified character: Match the casing of the previous character
        result.write(
          isUpperCase(original[i - 1])
              ? corrected[i].toUpperCase()
              : corrected[i].toLowerCase(),
        );
      } else {
        // Otherwise, match the casing of the following character
        result.write(
          isUpperCase(original[i + 1])
              ? corrected[i].toUpperCase()
              : corrected[i].toLowerCase(),
        );
      }
    } else {
      // If the character matches, preserve it as is
      result.write(original[i]);
    }
  }

  return result.toString();
}

/// Normalizes the casing of the input string by processing each sentence.
///
/// This function takes a [String] [input] and returns a new string with the casing
/// normalized. It processes the input by breaking it into sentences, and then
/// applies the following rules to each sentence:
///
/// - If most of the letters in the sentence are uppercase, the entire sentence
///   is converted to uppercase.
/// - Otherwise, the first letter of the sentence is capitalized, and the rest
///   of the sentence is converted to lowercase.
///
/// The function handles various sentence-ending characters (`.`, `!`, `?`, `\n`)
/// and preserves any non-letter characters in the input.
String normalizeCasing(final String input) {
  if (input.isEmpty) {
    return input;
  }

  // Define sentence-ending characters
  const List<String> sentenceEndings = ['.', '!', '?', '\n'];

  StringBuffer result = StringBuffer();
  StringBuffer currentSentence = StringBuffer();
  int uppercaseCount = 0;
  int letterCount = 0;

  /// Process the current sentence buffer
  void processCurrentSentence() {
    if (currentSentence.isEmpty) {
      return;
    }

    String sentence = currentSentence.toString();

    // If most letters in the sentence are uppercase, convert the whole sentence to uppercase
    if (letterCount > 0 && uppercaseCount / letterCount > 0.5) {
      result.write(sentence.toUpperCase());
    } else {
      // Find the first letter in the sentence to capitalize
      int firstLetterIndex = sentence.split('').indexWhere(
            (char) => isLetter(char),
          ); // Check for letters

      if (firstLetterIndex != -1) {
        // Capitalize the first letter and lowercase the rest
        result.write(
          sentence.substring(0, firstLetterIndex),
        ); // Non-letter prefix
        result.write(sentence[firstLetterIndex]);
        result.write(sentence.substring(firstLetterIndex + 1).toLowerCase());
      } else {
        // No letters found, just append the sentence
        result.write(sentence);
      }
    }

    // Clear sentence buffers
    currentSentence.clear();
    uppercaseCount = 0;
    letterCount = 0;
  }

  for (int i = 0; i < input.length; i++) {
    String char = input[i];

    if (char == '\n') {
      // Process the current sentence and add the newline
      processCurrentSentence();
      result.write('\n');
    } else {
      currentSentence.write(char);

      // Update uppercase and letter counts
      if (char.trim().isNotEmpty) {
        if (isUpperCase(char)) {
          uppercaseCount++;
        }
        if (isLetter(char)) {
          letterCount++;
        }
      }

      // If the character is a sentence-ending character, process the sentence
      if (sentenceEndings.contains(char)) {
        processCurrentSentence();
      }
    }
  }

  // Process any remaining sentence
  processCurrentSentence();

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

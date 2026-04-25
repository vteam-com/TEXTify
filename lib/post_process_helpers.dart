/// Shared utility functions and constants for OCR post-processing passes.
library;

const int spaceCodeUnit = 32;
const int tabCodeUnit = 9;
const int lineFeedCodeUnit = 10;
const int carriageReturnCodeUnit = 13;
const int uppercaseACodeUnit = 65;
const int uppercaseZCodeUnit = 90;
const int lowercaseACodeUnit = 97;
const int lowercaseZCodeUnit = 122;
const int digitZeroCodeUnit = 48;
const int digitNineCodeUnit = 57;
const int asciiCaseOffset = 32;
const int regexGroupFirst = 1;
const int regexGroupSecond = 2;

/// Returns true when [code] is an ASCII uppercase letter.
bool isUpper(int code) =>
    code >= uppercaseACodeUnit && code <= uppercaseZCodeUnit;

/// Returns true when [code] is an ASCII lowercase letter.
bool isLower(int code) =>
    code >= lowercaseACodeUnit && code <= lowercaseZCodeUnit;

/// Returns true when [code] is an ASCII letter.
bool isLetter(int code) => isUpper(code) || isLower(code);

/// Returns true when [code] is an ASCII digit.
bool isDigit(int code) =>
    code >= digitZeroCodeUnit && code <= digitNineCodeUnit;

/// Converts the first alphabetic character in a line to uppercase.
String sentenceCase(String line) {
  final StringBuffer buffer = StringBuffer();
  bool capitalized = false;
  for (int i = 0; i < line.length; i++) {
    final String ch = line[i];
    final int code = ch.codeUnitAt(0);
    if (!capitalized && isLetter(code)) {
      buffer.writeCharCode(isLower(code) ? code - asciiCaseOffset : code);
      capitalized = true;
      continue;
    }
    buffer.write(ch);
  }
  return buffer.toString();
}

/// Returns true when [word] follows strict ASCII title-case.
///
/// A strict title-case word has an uppercase first letter and lowercase
/// letters for all remaining characters.
bool isTitleCaseWord(String word) {
  if (word.isEmpty) {
    return false;
  }

  final int first = word.codeUnitAt(0);
  if (!isUpper(first)) {
    return false;
  }

  for (int i = 1; i < word.length; i++) {
    final int code = word.codeUnitAt(i);
    if (!isLower(code)) {
      return false;
    }
  }

  return true;
}

/// Converts [word] to strict ASCII title-case.
///
/// The result has an uppercase first letter and lowercase remaining letters.
String toTitleCaseWord(String word) {
  if (word.isEmpty) {
    return word;
  }

  final String lower = word.toLowerCase();
  if (lower.length == 1) {
    return lower.toUpperCase();
  }

  return '${lower[0].toUpperCase()}${lower.substring(1)}';
}

/// Returns true if the token is mixed-case (e.g., 'OpenAI').
bool isMixedCase(String token) {
  if (token.length < minMixedCaseTokenLength) return false;
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
bool isAcronym(String token) {
  if (token.length < minAcronymTokenLength) return false;
  final String alpha = token.replaceAll(RegExp(r'[^A-Za-z]'), '');
  return alpha.isNotEmpty && alpha == alpha.toUpperCase();
}

/// Returns true when [value] contains only ASCII letters.
bool isAlphaWord(String value) => RegExp(r'^[A-Za-z]+$').hasMatch(value);

const int minMixedCaseTokenLength = 3;
const int minAcronymTokenLength = 2;

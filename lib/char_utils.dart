/// This library is part of the Textify package.
/// Provides shared character classification utilities used across the project.
library;

const int _uppercaseA = 65;
const int _uppercaseZ = 90;
const int _lowercaseA = 97;
const int _lowercaseZ = 122;
const int _digit0 = 48;
const int _digit9 = 57;

/// Checks whether the given string is all uppercase.
bool isUpperCase(final String str) {
  return str == str.toUpperCase();
}

/// Checks whether the given string is a single digit from 0 to 9.
bool isDigit(final String char) {
  if (char.length != 1) {
    return false;
  }
  final int code = char.codeUnitAt(0);
  return code >= _digit0 && code <= _digit9;
}

/// Checks whether the given character is a letter.
bool isLetter(final String character) {
  return character.toLowerCase() != character.toUpperCase();
}

/// True when [character] is a single ASCII uppercase letter.
bool isUppercaseLetter(String character) {
  if (character.length != 1) {
    return false;
  }
  final int codeUnit = character.codeUnitAt(0);
  return codeUnit >= _uppercaseA && codeUnit <= _uppercaseZ;
}

/// True when [character] is a single ASCII lowercase letter.
bool isLowercaseLetter(String character) {
  if (character.length != 1) {
    return false;
  }
  final int codeUnit = character.codeUnitAt(0);
  return codeUnit >= _lowercaseA && codeUnit <= _lowercaseZ;
}

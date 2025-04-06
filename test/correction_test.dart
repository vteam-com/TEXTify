import 'package:flutter_test/flutter_test.dart';
import 'package:textify/correction.dart';

void main() {
  group('Text Correction Tests', () {
    test('isUpperCase, isDigit, isLetter utility functions', () {
      expect(isUpperCase('A'), true);
      expect(isUpperCase('a'), false);

      expect(isDigit('5'), true);
      expect(isDigit('A'), false);

      expect(isLetter('A'), true);
      expect(isLetter('5'), false);
    });

    test('applyCorrection with dictionary disabled', () {
      const String input = 'Hell0 W0rld';
      final String result = applyCorrection(input, false);
      expect(result, 'Hello World');
    });

    test('wordReplaceDigit0 converts 0 to O/o in text contexts', () {
      expect(replaceBadDigitsKeepCasing('Hell0'), 'Hello');
      expect(replaceBadDigitsKeepCasing('W0RLD'), 'WORLD');
      expect(replaceBadDigitsKeepCasing('123'), '123'); // Not mostly letters
    });

    test('digitCorrection converts letter-like characters to digits', () {
      CharacterStats stats = CharacterStats();
      stats.inspect('');
      expect(stats.mostlyDigits(), false);

      stats.inspect('0123456789');
      expect(stats.mostlyDigits(), true);

      stats.inspect('123O');
      expect(stats.mostlyDigits(), true);
      expect(digitCorrection('123O'), '1230');

      stats.inspect('l23O');
      expect(stats.mostlyDigits(), false);
      expect(
        digitCorrection('l23O'),
        '1230',
      );
    });

    test('applyCorrection with dictionary disabled', () {
      const String input = 'Hell0 W0rld';
      final String result = applyCorrection(input, false);
      expect(result, 'Hello World');
    });

    test('applyCorrection with dictionary enabled with not input error', () {
      const String input = 'Hello World';
      final String result = applyCorrection(input, true);
      expect(result, 'Hello world');
    });

    test('applyCorrection with dictionary enabled with input error text', () {
      const String input = 'HellB W0rld';
      final String result = applyCorrection(input, true);
      expect(result, 'Hello world');
    });

    test('applyCorrection handles multi-line text', () {
      const String input = 'Hell0 W0rld\nG00d M0rning';
      final String result = applyCorrection(input, true);
      expect(result, 'Hello world\nGood morning');
    });

    test('findClosestWord finds similar words', () {
      final Set<String> dictionary = {'apple', 'banana', 'orange'};
      expect(findClosestWord(dictionary, 'appie'), 'apple');
      expect(findClosestWord(dictionary, 'oronge'), 'orange');
      expect(findClosestWord(dictionary, 'xyz'), 'apple');
    });

    test('levenshteinDistance calculates edit distance', () {
      expect(levenshteinDistance('apple', 'oragne'), 5);
      expect(levenshteinDistance('apple', 'annas'), 4);
      expect(levenshteinDistance('', 'abc'), 3);
      expect(levenshteinDistance('abc', ''), 3);
      expect(levenshteinDistance('abc', 'abc'), 0);
    });

    test('normalizeCasing handles different casing patterns', () {
      expect(normalizeCasingOfParagraph('hello world'), 'Hello world');
      expect(normalizeCasingOfParagraph('HELLO WORLD'), 'HELLO WORLD');
      expect(normalizeCasingOfParagraph('hello. world'), 'Hello. World');
    });

    test(
        'findClosestMatchingWordInDictionary finds closest match and preserves casing',
        () {
      // Test case 1: No match found, should find closest word
      String result1 = findClosestMatchingWordInDictionary('appLe');
      expect(result1, 'appLe'); // Should preserve casing of unchanged letters

      // Test case 2: Match already found, should return original word
      String result2 = findClosestMatchingWordInDictionary('baNana');
      expect(result2, 'baNana');

      // Test case 3: Plural word ending with 's'
      String result3 = findClosestMatchingWordInDictionary('oranges');
      expect(result3, 'oranges'); // Should preserve the 's' at the end

      // Test case 4: Word with different length than suggestion
      String result4 = findClosestMatchingWordInDictionary('helloz');
      expect(result4, 'hello'); // Should handle different length words
    });
  });
}

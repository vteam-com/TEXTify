import 'package:flutter_test/flutter_test.dart';
import 'package:textify/char_utils.dart';
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

    test('CharacterStats tracks spaces and counters', () {
      final CharacterStats stats = CharacterStats();
      stats.inspect('A b 9');
      expect(stats.letters, 2);
      expect(stats.digits, 1);
      expect(stats.spaces, 2);
      expect(stats.uppercase, 2);
      expect(stats.lowercase, 1);
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
      expect(digitCorrection('l23O'), '1230');
    });

    test('applyCorrection with dictionary disabled', () {
      const String input = 'Hell0 W0rld';
      final String result = applyCorrection(input, false);
      expect(result, 'Hello World');
    });

    test('applyCorrection with dictionary enabled with not input error', () {
      const String input = 'Hello World';
      final String result = applyCorrection(input, true);
      expect(result, 'Hello World');
    });

    test('applyCorrection with dictionary enabled with input error text', () {
      const String input = 'HellB W0rld';
      final String result = applyCorrection(input, true);
      expect(result, 'Hello World');
    });

    test(
      'dictionary correction keeps word length and supports i/l confusion',
      () {
        const String input = 'heii';
        final String result = applyCorrection(input, true);
        expect(result.length, input.length);
        expect(result.toLowerCase(), isNot('hello'));
      },
    );

    test('applyCorrection handles multi-line text', () {
      const String input = 'Hell0 W0rld\nG00d M0rning';
      final String result = applyCorrection(input, true);
      expect(result, 'Hello World\nGood Morning');
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
      // Title case / mixed case with acronyms should be preserved
      expect(
        normalizeCasingOfParagraph('OpenAI Released GPT In 2020'),
        'OpenAI Released GPT In 2020',
      );
      expect(
        normalizeCasingOfParagraph('Version 4 Arrived In March'),
        'Version 4 Arrived In March',
      );
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

        // Test case 4: Word with close dictionary match
        String result4 = findClosestMatchingWordInDictionary('helloz');
        expect(result4, 'hellos'); // 'hellos' is distance 1, same length.
      },
    );

    test(
      'applyDictionaryCorrectionOnSingleSentence rejects non-OCR-confusion fallback',
      () {
        const Map<String, List<String>> correctionLetters = {
          '0': ['O', 'o', 'B', '8'],
          '5': ['S', 's'],
          'l': ['I', 'L', '1', 'i', '!'],
          'i': ['l', 'I', '1', '!'],
          'I': ['l', 'i', '1', '!'],
          'S': ['5'],
          'o': ['D', '0'],
          'O': ['D', '0'],
          '!': ['T', 'I', 'i', 'l', '1'],
          '@': ['A', 'a'],
        };

        // z→s is NOT an OCR confusion, so the fallback is rejected.
        final String result = applyDictionaryCorrectionOnSingleSentence(
          'helloz',
          correctionLetters,
        );
        expect(result, 'Helloz');
      },
    );

    test(
      'applyDictionaryCorrectionOnSingleSentence accepts OCR-confusion fallback',
      () {
        const Map<String, List<String>> correctionLetters = {
          '0': ['O', 'o', 'B', '8'],
          '5': ['S', 's'],
          'l': ['I', 'L', '1', 'i', '!'],
          'i': ['l', 'I', '1', '!'],
          'I': ['l', 'i', '1', '!'],
          'S': ['5'],
          'o': ['D', '0'],
          'O': ['D', '0'],
          '!': ['T', 'I', 'i', 'l', '1'],
          '@': ['A', 'a'],
        };

        // 1→l IS an OCR confusion (l's list includes '1'), so fallback accepted.
        final String result = applyDictionaryCorrectionOnSingleSentence(
          'he1lo',
          correctionLetters,
        );
        expect(result, 'Hello');
      },
    );
  });
}

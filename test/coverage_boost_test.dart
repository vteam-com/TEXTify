import 'package:flutter_test/flutter_test.dart';
import 'package:textify/textify_post_process.dart';
import 'package:textify/correction.dart';

void main() {
  group('Coverage Boost Tests', () {
    test('CharacterStats edge cases', () {
      final stats = CharacterStats('!!!');
      expect(stats.punctuation, 3);
      expect(stats.mostlyPunctuation(), true);

      final emptyStats = CharacterStats('');
      expect(emptyStats.mostlyPunctuation(), false);
      expect(emptyStats.mostlyUppercase(), false);
    });

    test('PostProcess empty and whitespace', () {
      expect(postProcessText(''), '');
      expect(postProcessText('\n\n'), '\n\n');
    });

    test('Case normalization outliers', () {
      // 3-letter word with 1 outlier
      expect(postProcessText('AbC'), 'ABC');
      expect(postProcessText('aBc'), 'Abc');
      // Title case preservation
      expect(postProcessText('Abc'), 'Abc');
    });

    test('Numeric gaps and date separators', () {
      // Digit dominant line whitespace removal
      expect(postProcessText('1 2 3'), '123');
      // Date separators
      expect(postProcessText('2025 / 12 / 31'), '2025/12/31');
      expect(postProcessText('12 . 31'), '12.31');
    });

    test('Fragment merging protection', () {
      // Should not merge two valid words
      expect(postProcessText('THE DOG'), 'THE DOG');
      // Should merge if one is fragment
      // Note: 'TH' and 'E' might both be in dictionary if 'TH' is allowed,
      // but let's use something definitely not in dictionary.
      // Actually 'DOGG' + 'Y' -> 'DOGGY'
      expect(postProcessText('DOGG Y'), 'DOGGY');
    });

    test('Punctuation heavy line preservation', () {
      final longPunct = '(){}[]<>/,;:.!@#\$&*-+=?';
      expect(postProcessText(longPunct), longPunct);

      final shortNoise = '.,';
      expect(postProcessText(shortNoise), '');
    });

    test('Sentence case with leading non-letters', () {
      // This hits the branch where capitalized is set
      expect(postProcessText('  hello'), '  Hello');
      expect(postProcessText('1. hello'), '1. Hello');
    });

    test('Dictionary correction with symbols', () {
      // Symbols should skip dictionary correction
      final input = '!!! ( ) !!!';
      expect(applyCorrection(input, true), input);
    });

    test('More CharacterStats coverage', () {
      final stats = CharacterStats();
      stats.inspect('123abcABC !');
      expect(stats.digits, 3);
      expect(stats.letters, 6);
      expect(stats.uppercase, 7); // 3 letters (ABC) + 3 digits + 1 punct
      expect(stats.lowercase, 3);
      expect(stats.punctuation, 1);
      expect(stats.spaces, 1);
      expect(stats.mostlyDigits(), false);
      expect(stats.mostlyUppercase(), true); // 7/6 > 0.9
    });

    test('CharacterStats reset and edge cases', () {
      final stats = CharacterStats('ABC');
      expect(stats.letters, 3);
      stats.reset();
      expect(stats.letters, 0);

      final noLetters = CharacterStats('123');
      expect(noLetters.mostlyUppercase(), false);
    });

    test('Apply correction without dictionary', () {
      expect(applyCorrection('word', false), 'word');
    });

    test('Post process without dictionary', () {
      expect(postProcessText('DOGG Y', applyDictionary: false), 'DOGG Y');
    });
  });
}

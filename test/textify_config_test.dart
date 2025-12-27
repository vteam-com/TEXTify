import 'package:flutter_test/flutter_test.dart';
import 'package:textify/models/textify_config.dart';

void main() {
  group('TextifyConfig', () {
    test('default constructor creates balanced configuration', () {
      final config = TextifyConfig();
      expect(config.dilationSize, equals(22));
      expect(config.excludeLongLines, isTrue);
      expect(config.attemptCharacterSplitting, isTrue);
      expect(config.applyDictionaryCorrection, isFalse);
      expect(config.matchingThreshold, equals(0.4));
      expect(config.maxProcessingTimeMs, equals(30000));
    });

    test('fast configuration has expected values', () {
      final config = TextifyConfig.fast;
      expect(config.dilationSize, equals(15));
      expect(config.excludeLongLines, isFalse);
      expect(config.attemptCharacterSplitting, isFalse);
      expect(config.applyDictionaryCorrection, isFalse);
      expect(config.matchingThreshold, equals(0.3));
    });

    test('accurate configuration has expected values', () {
      final config = TextifyConfig.accurate;
      expect(config.dilationSize, equals(30));
      expect(config.excludeLongLines, isTrue);
      expect(config.attemptCharacterSplitting, isTrue);
      expect(config.applyDictionaryCorrection, isTrue);
      expect(config.matchingThreshold, equals(0.6));
    });

    test('robust configuration has expected values', () {
      final config = TextifyConfig.robust;
      expect(config.dilationSize, equals(35));
      expect(config.excludeLongLines, isTrue);
      expect(config.attemptCharacterSplitting, isTrue);
      expect(config.applyDictionaryCorrection, isTrue);
      expect(config.matchingThreshold, equals(0.5));
    });

    test('custom configuration accepts all parameters', () {
      final config = TextifyConfig(
        dilationSize: 25,
        excludeLongLines: false,
        attemptCharacterSplitting: false,
        applyDictionaryCorrection: true,
        matchingThreshold: 0.8,
        maxProcessingTimeMs: 60000,
      );

      expect(config.dilationSize, equals(25));
      expect(config.excludeLongLines, isFalse);
      expect(config.attemptCharacterSplitting, isFalse);
      expect(config.applyDictionaryCorrection, isTrue);
      expect(config.matchingThreshold, equals(0.8));
      expect(config.maxProcessingTimeMs, equals(60000));
    });

    test('throws assertion error for invalid dilationSize', () {
      expect(
        () => TextifyConfig(dilationSize: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => TextifyConfig(dilationSize: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('throws assertion error for invalid matchingThreshold', () {
      expect(
        () => TextifyConfig(matchingThreshold: -0.1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => TextifyConfig(matchingThreshold: 1.1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('throws assertion error for invalid maxProcessingTimeMs', () {
      expect(
        () => TextifyConfig(maxProcessingTimeMs: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => TextifyConfig(maxProcessingTimeMs: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('toString returns descriptive string', () {
      final config = TextifyConfig();
      final string = config.toString();
      expect(string, contains('TextifyConfig'));
      expect(string, contains('dilationSize: 22'));
      expect(string, contains('excludeLongLines: true'));
    });

    test('equality works correctly', () {
      final config1 = TextifyConfig();
      final config2 = TextifyConfig();
      final config3 = TextifyConfig(dilationSize: 25);

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
      expect(config1, isNot(equals('not a config')));
      expect(config1, equals(config1)); // Test identical check
    });

    test('hashCode is consistent with equality', () {
      final config1 = TextifyConfig();
      final config2 = TextifyConfig();

      expect(config1.hashCode, equals(config2.hashCode));
    });

    test('copyWith creates new instance with updated fields', () {
      final original = TextifyConfig();
      final copied = original.copyWith(
        dilationSize: 25,
        excludeLongLines: false,
        applyDictionaryCorrection: true,
      );

      // Check that a new instance is created
      expect(copied, isNot(same(original)));

      // Check updated fields
      expect(copied.dilationSize, equals(25));
      expect(copied.excludeLongLines, isFalse);
      expect(copied.applyDictionaryCorrection, isTrue);

      // Check unchanged fields
      expect(
        copied.attemptCharacterSplitting,
        equals(original.attemptCharacterSplitting),
      );
      expect(copied.matchingThreshold, equals(original.matchingThreshold));
      expect(copied.maxProcessingTimeMs, equals(original.maxProcessingTimeMs));
    });

    test('copyWith with null values keeps original values', () {
      final original = TextifyConfig(dilationSize: 25);
      final copied = original.copyWith();

      expect(copied.dilationSize, equals(25));
      expect(copied.excludeLongLines, equals(original.excludeLongLines));
    });
  });
}

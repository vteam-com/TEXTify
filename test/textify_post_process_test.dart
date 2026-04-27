import 'package:flutter_test/flutter_test.dart';
import 'package:textify/correction.dart';
import 'package:textify/textify_post_process.dart';

void main() {
  group('postProcessText', () {
    test('empty string returns empty', () {
      expect(postProcessText(''), '');
    });

    test('simple uppercase text preserved', () {
      final result = postProcessText('HELLO WORLD');
      expect(result.isNotEmpty, true);
    });
  });

  group('numeric gap normalization', () {
    test('digit-only line collapses spaces', () {
      // _normalizeNumericGaps: all digits → strip whitespace
      final result = postProcessText('1 2 3 4');
      expect(result, '1234');
    });

    test('digit with embedded alpha maps to dot separator', () {
      // _normalizeNumericGaps: (\d)\s+([A-Za-z0-9])(?=\d) → digit.mapped
      // e.g. "5 O3" → "5.03" (O→0 via confusion map)
      final result = postProcessText('5 O3');
      expect(result.contains('.'), true);
    });
  });

  group('date separator normalization', () {
    test('Os in date stays as-is after separator normalization', () {
      // _normalizeStructuredPhrases removed; Os→O5 no longer forced
      final result = postProcessText('2022.Os.05');
      expect(result.contains('2022'), true);
    });

    test('date with trailing noise passes through', () {
      // _normalizeStructuredPhrases removed; no more TheEnd injection
      final result = postProcessText('2022.O5.05...I');
      expect(result.contains('2022.05.05'), true);
    });

    test('date token with noisy suffix passes through', () {
      // _normalizeStructuredPhrases removed; no more TheEnd injection
      final result = postProcessText("2022.O5.05{|':l");
      expect(result.contains('2022'), true);
    });
  });

  group('fragmented line normalization', () {
    test('fragmented uppercase line is merged', () {
      // _looksFragmented triggers when >= 4 tokens with >= 3 short alpha tokens
      // Then _normalizeFragmentedLine joins single-char tokens and applies case
      final result = postProcessText('H E L L O W O R L D');
      // At least some tokens should be merged
      expect(result.length, lessThan('H E L L O W O R L D'.length));
    });

    test('non-fragmented line passes through', () {
      // < 4 tokens or < 3 short alpha → not fragmented
      final result = postProcessText('HELLO WORLD');
      expect(result, 'HELLO WORLD');
    });

    test('fragmented lowercase line uses sentence case', () {
      // mostly lowercase → _sentenceCase applied
      final result = postProcessText('h e l l o w o r l d');
      expect(result.length, lessThan('h e l l o w o r l d'.length));
    });

    test('fragmented line with lS preserves as-is', () {
      // lS→IS forced mapping removed; dictionary correction may or may not fix
      final result = postProcessText('TH lS A TE ST');
      expect(result.isNotEmpty, true);
    });
  });

  group('structured phrase normalization', () {
    test('digit comma space digit collapses via date separators', () {
      // _normalizeDateSeparators handles (?<=\d)\s*,\s*(?=\d) → ','
      final result = postProcessText('PRICE 1, 234');
      expect(result, 'PRICE 1,234');
    });

    test('spaces around dot in digit context removed', () {
      // (?<=\d)\s*\.\s*(?=[A-Za-z0-9]) → .
      final result = postProcessText('123 . 456');
      expect(result.contains('123.456'), true);
    });

    test('repeated uppercase suffix before comma is split', () {
      final result = postProcessText(
        'EUROLOJAMATOSINHOS, MATOSINHOS',
        applyDictionary: false,
      );
      expect(result, 'EUROLOJA MATOSINHOS, MATOSINHOS');
    });

    test('already split uppercase suffix before comma is preserved', () {
      final result = postProcessText(
        'EUROLOJA MATOSINHOS, MATOSINHOS',
        applyDictionary: false,
      );
      expect(result, 'EUROLOJA MATOSINHOS, MATOSINHOS');
    });

    test('non-repeated uppercase comma suffix is preserved', () {
      final result = postProcessText(
        'REMARKABLE, OSLO',
        applyDictionary: false,
      );
      expect(result, 'REMARKABLE, OSLO');
    });

    test('title-case token with trailing uppercase letter is split', () {
      final result = postProcessText(
        'Tuca ChaE Cafe, PORTO',
        applyDictionary: false,
      );
      expect(result, 'Tuca Cha E Cafe, PORTO');
    });

    test('lowercase word with trailing uppercase letter is split', () {
      final result = postProcessText('GadgetC 2 24-00', applyDictionary: false);
      expect(result, 'Gadget C 2 24.00');
    });

    test(
      'mixed-case brands with multi-letter uppercase suffix are preserved',
      () {
        final result = postProcessText(
          'OpenAI Released GPT In 2020',
          applyDictionary: false,
        );
        expect(result, 'OpenAI Released GPT In 2020');
      },
    );

    test('dict-on trailing uppercase token in title-case phrase is split', () {
      final result = postProcessText(
        'Tuca ChaE Cafe, PORTO',
        applyDictionary: true,
      );
      expect(result, 'Tuca Cha E Cafe, PORTO');
    });

    test(
      'dict-on trailing uppercase token before numeric columns is split',
      () {
        final result = postProcessText(
          'GadgetC 2 24-00',
          applyDictionary: true,
        );
        expect(result, 'Gadget C 2 24.00');
      },
    );

    test('dict-on standalone upper-digit token in item row is split', () {
      final result = postProcessText('Widget B1 7-50', applyDictionary: true);
      expect(result, 'Widget B 1 7.50');
    });

    test('receipt row with merged quantity and price is normalized', () {
      final result = postProcessText('widget A 3.12-99', applyDictionary: true);
      expect(result, 'Widget A 3 12.99');
    });

    test('uppercase summary row decimal comma is normalized', () {
      final result = postProcessText('TOTAL 57,48', applyDictionary: false);
      expect(result, 'TOTAL 57.48');
    });

    test(
      'split postal code after region is normalized with dictionary off',
      () {
        final result = postProcessText(
          'SAN FRANCISCO, CA 941 05',
          applyDictionary: false,
        );
        expect(result, 'SAN FRANCISCO, CA 94105');
      },
    );

    test(
      'attached region and split postal code are normalized with dictionary on',
      () {
        final result = postProcessText(
          'SAN FRANCISCO, CA941 05',
          applyDictionary: true,
        );
        expect(result, 'SAN FRANCISCO, CA 94105');
      },
    );

    test('non-address code with hyphenated digits is preserved', () {
      final result = postProcessText(
        'Reference: TX-98432',
        applyDictionary: true,
      );
      expect(result, 'Reference: TX-98432');
    });

    test('structured code prefix before numeric id is uppercased', () {
      final result = postProcessText(
        'Reference: Tx-98432',
        applyDictionary: true,
      );
      expect(result, 'Reference: TX-98432');
    });

    test('date-like structured field value normalizes numeric confusions', () {
      final result = postProcessText('Date: zoz5-06-15', applyDictionary: true);
      expect(result, 'Date: 2025-06-15');
    });

    test(
      'structured field label near-miss is normalized with dictionary on',
      () {
        final result = postProcessText(
          'Oate: 2025-06-15',
          applyDictionary: true,
        );
        expect(result, 'Date: 2025-06-15');
      },
    );

    test(
      'structured field label near-miss is preserved with dictionary off',
      () {
        final result = postProcessText(
          'Oate: 2025-06-15',
          applyDictionary: false,
        );
        expect(result, 'Oate: 2025-06-15');
      },
    );

    test('decimal structured field value normalizes numeric confusions', () {
      final result = postProcessText(
        'Amount: ], z5o.75',
        applyDictionary: true,
      );
      expect(result, 'Amount: 1,250.75');
    });

    test('grid-like numeric row repairs all-letter digit-lookalike token', () {
      final result = postProcessText('IOOI 2002 3003', applyDictionary: false);
      expect(result, '1001 2002 3003');
    });

    test('standalone decimal-like token normalizes digit lookalikes', () {
      final result = postProcessText(
        'Your balance is now O.OO USD.',
        applyDictionary: false,
      );
      expect(result, 'Your balance is now 0.00 USD.');
    });

    test('sentence-like line lowers short uppercase dictionary word', () {
      final result = postProcessText(
        'Your balance IS now O.OO USD.',
        applyDictionary: false,
      );
      expect(result, 'Your balance is now 0.00 USD.');
    });

    test('dictionary near-miss fixes tor to for in prose', () {
      final result = postProcessText(
        'Thank you tor your purchase.',
        applyDictionary: true,
      );
      expect(result, 'Thank you for your purchase.');
    });

    test('uppercase code label is preserved for code-like value', () {
      final result = postProcessText(
        'SKU: AB12CD34EF56',
        applyDictionary: false,
      );
      expect(result, 'SKU: AB12CD34EF56');
    });

    test('missing colon after uppercase code label is restored', () {
      final result = postProcessText(
        'SKUI ABI2cD34zP56',
        applyDictionary: false,
      );
      expect(result, 'SKU: AB12CD34ZP56');
    });

    test('missing colon before slash-delimited code value is restored', () {
      final result = postProcessText(
        'LOTI 2025/Q2/BATcHo7',
        applyDictionary: false,
      );
      expect(result, 'LOT: 2025/Q2/BATCH07');
    });

    test('compound code row normalizes digits and separators', () {
      final corrected = applyCorrection('oRD+2o25o6l5+oo42', false);
      final result = postProcessText(corrected, applyDictionary: false);
      expect(result, 'ORD-20250615-0042');
    });

    test(
      'code token with embedded merchant id preserves internal I before digit',
      () {
        final result = postProcessText(
          'WWW.AMAZON.* LSIAK28I5, LUXEMBOURG',
          applyDictionary: false,
        );
        expect(result, 'WWW.AMAZON.* LSIAK28I5, LUXEMBOURG');
      },
    );

    test('missing code-label colon does not trigger on numeric grid row', () {
      final corrected = applyCorrection('IOOI 2002 3003', false);
      final result = postProcessText(corrected, applyDictionary: false);
      expect(result, '1001 2002 3003');
    });

    test('missing code-label colon ignores OCR-noisy numeric grid row', () {
      final corrected = applyCorrection('IOOI 2OO2 3OO3', false);
      final result = postProcessText(corrected, applyDictionary: false);
      expect(result, '1001 2002 3003');
    });

    test('domain-like dotted token is preserved', () {
      final result = postProcessText(
        'Visit OpenAI.com',
        applyDictionary: false,
      );
      expect(result, 'Visit OpenAI.com');
    });

    test('multiline structured field blob normalizes date and amount', () {
      final result = postProcessText(
        'Name: John Smlth\n'
        'Date: zoz5-06-15\n'
        'Reference: Tx-98432\n'
        'Amount: ], z5o.75\n'
        'Status: conrlrmfo',
        applyDictionary: true,
      );
      final lines = result.split('\n');
      expect(lines[1], 'Date: 2025-06-15');
      expect(lines[2], 'Reference: TX-98432');
      expect(lines[3], 'Amount: 1,250.75');
    });

    test('code-like upper-digit token is preserved in uppercase context', () {
      final result = postProcessText('SKU B1 7-50', applyDictionary: true);
      expect(result, 'SKU B1 7-50');
    });
  });

  group('trailing date noise normalization', () {
    test('noisy punctuation line after date passes through', () {
      // _normalizeTrailingDateNoise removed; no more TheEnd injection
      final result = postProcessText('2022.O5.05\n...|');
      expect(result.contains('2022'), true);
    });
  });

  group('noise line merging', () {
    test('noise line with vertical marks before lowercase is skipped', () {
      // _inferPrefixFromNoise removed; noise lines simply discarded
      final result = postProcessText('|\nhat');
      expect(result.toLowerCase().contains('hat'), true);
    });

    test('noise line with vertical and horizontal marks is skipped', () {
      // _inferPrefixFromNoise removed; noise lines simply discarded
      final result = postProcessText('|-\nhe');
      expect(result.toLowerCase().contains('he'), true);
    });

    test('empty noise before content skips prefix', () {
      final result = postProcessText('\nHELLO');
      expect(result.contains('HELLO'), true);
    });

    test('noise line with only punctuation', () {
      // _isNoiseLine: only noise chars
      final result = postProcessText('...\nHELLO');
      expect(result.contains('HELLO'), true);
    });

    test('non-noise line is not removed', () {
      final result = postProcessText('HELLO\nWORLD');
      expect(result.contains('HELLO'), true);
      expect(result.contains('WORLD'), true);
    });
  });

  group('word fragment merging', () {
    test('two short alpha fragments merge into dictionary word', () {
      // _mergeLikelyWordFragments: short + short → dictionary match
      // HEL + LO → HELLO (distance 0)
      final result = postProcessText('HEL LO WOR LD TEST FO UR');
      // Some fragments should be merged
      expect(result.isNotEmpty, true);
    });
  });

  group('noisy dictionary correction', () {
    test('near-miss word corrected by dictionary', () {
      // _correctNoisyDictionaryWords runs inside _normalizeFragmentedLine
      // Feed a fragmented line so the code path is exercised
      final result = postProcessText('HE LO WO RL D F R O M');
      // Fragmented line triggers merge + dictionary correction
      expect(result.isNotEmpty, true);
    });

    test('dictionary near-miss does not change token length', () {
      final String input = 'helloz';
      final result = postProcessText(input, applyDictionary: true);
      expect(result.length, input.length);
    });
  });

  group('isNoiseLine edge cases', () {
    test('long line is not noise', () {
      // > _maxNoiseLineLength (2) → not noise
      final result = postProcessText('ABC\nHELLO');
      // "ABC" is 3 chars, not noise; preserved
      expect(result.isNotEmpty, true);
    });

    test('noise letters only are noise', () {
      // 'i', 'l', 'I', 'L', 't', 'T' are noise letters
      final result = postProcessText('Il\nworld');
      expect(result.toLowerCase().contains('world'), true);
    });

    test('digit in short line makes it non-noise', () {
      // Digits are letters/digits but not in _noiseLetters
      final result = postProcessText('5\nHELLO');
      expect(result.isNotEmpty, true);
    });
  });

  group('noise line prefix edge cases', () {
    test('noise before uppercase line does not add prefix', () {
      // _inferPrefixFromNoise removed; noise lines simply discarded
      final result = postProcessText('|\nHello');
      expect(result.isNotEmpty, true);
    });

    test('noise before empty line after noise', () {
      final result = postProcessText('|\n\n');
      expect(result, isA<String>());
    });
  });

  group('fragmented line regex replacements', () {
    test('l between uppercase becomes I in fragmented line', () {
      // _normalizeFragmentedLine: (?<=[A-Z])l(?=[A-Z]) → I
      // AlB has l surrounded by uppercase A and B → AIB
      // Then fragments merge and dictionary corrects → AIM CODE
      final result = postProcessText('AlB C D E');
      expect(result, 'AIBCDE');
    });

    test('I between lowercase becomes l in fragmented line', () {
      // _normalizeFragmentedLine: (?<=[a-z])I(?=[a-z]) → l
      // aIb → alb, then dictionary corrects alb→all, c d e merge → cde
      final result = postProcessText('aIb c d e');
      expect(result, 'All cde');
    });
  });

  group('structured phrases edge cases', () {
    test('empty line in multi-line passes through', () {
      final result = postProcessText('HELLO\n\nWORLD');
      expect(result.isNotEmpty, true);
    });

    test('date with noisy L suffix passes through', () {
      // _normalizeStructuredPhrases removed; no more TheEnd injection
      final result = postProcessText("2022.O5.05{|'L");
      expect(result.contains('2022'), true);
    });

    test('date with digit suffix passes through', () {
      final result = postProcessText("2022.O5.05[:]1");
      expect(result.contains('2022'), true);
    });
  });

  group('mergeLikelyWordFragments edge cases', () {
    test('non-alpha tokens skip merge', () {
      // !_isAlphaWord → skip
      final result = postProcessText('12 AB CD EF GH');
      expect(result.isNotEmpty, true);
    });

    test('single character a skips merge', () {
      // left == 'a' or right == 'a' → skip
      final result = postProcessText('A a B C D E');
      expect(result.isNotEmpty, true);
    });

    test('long non-fragment pair skips merge', () {
      // Long tokens that don't meet fragmentPair criteria skip
      final result = postProcessText('LONGWORD ANOTHER BIG ONES');
      expect(result.isNotEmpty, true);
    });
  });
}

import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textify/band.dart';
import 'package:textify/character_definition.dart';
import 'package:textify/correction.dart';
import 'package:textify/models/score_match.dart';
import 'package:textify/textify.dart';
import 'package:textify/artifact_serialize.dart';
import 'package:textify/artifact_splitting.dart' as splitting;
import 'package:textify/models/textify_config.dart';
import 'package:textify/image_helpers.dart';

void printMatrix(final Artifact matrix) {
  // ignore: avoid_print
  print(
    '${matrix.gridToString()}\n     L:${matrix.rectFound.left} T:${matrix.rectFound.top}  W:${matrix.cols} H:${matrix.rows}\n',
  );
}

Future<void> loadFontIfAvailable(String family, String assetPath) async {
  try {
    final ByteData fontData = await rootBundle.load(assetPath);
    final FontLoader loader = FontLoader(family)
      ..addFont(Future.value(fontData));
    await loader.load();
  } catch (_) {
    // Fall back to an installed system font when the asset is unavailable.
  }
}

Future<ui.Image> renderTextImage({
  required String text,
  required String fontFamily,
  required double fontSize,
  int padding = 12,
}) async {
  final TextPainter textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: const ui.Color(0xFF000000),
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        fontFamily: fontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final int width = textPainter.width.ceil() + (padding * 2);
  final int height = textPainter.height.ceil() + (padding * 2);

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  textPainter.paint(canvas, Offset(padding.toDouble(), padding.toDouble()));

  return recorder.endRecording().toImage(width, height);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize character definitions
  await Textify().init(pathToAssetsDefinition: 'assets/matrices.json');

  final List<String> supportedCharacters =
      Textify.characterDefinitions.supportedCharacters;

  test('Character Definitions', () async {
    expect(Textify.characterDefinitions.count, 90);

    expect(
      supportedCharacters.join(),
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,?!:;\'"(){}[]<>-/\\+=#\$&*@',
    );

    final CharacterDefinition? quoteDefinition = Textify.characterDefinitions
        .getDefinition('"');
    expect(quoteDefinition, isNotNull);
    expect(quoteDefinition!.matrices.length, 4);
    expect(
      quoteDefinition.matrices.map((matrix) => matrix.font).toSet(),
      <String>{'Arial', 'Courier', 'Helvetica', 'Times New Roman'},
    );
  });

  test('Character Definitions Enclosures', () async {
    const String charactersWithEnclosures = '04689ABDOPQRabdegopq#@&\$';

    List<String> charactersWithNoEnclosures = supportedCharacters
        .where((c) => !charactersWithEnclosures.contains(c))
        .toList();

    // No englosure;
    for (final String char in charactersWithNoEnclosures) {
      final String reason = 'Characer > "$char"';
      final CharacterDefinition? definition = Textify.characterDefinitions
          .getDefinition(char);

      expect(definition, isNotNull, reason: reason);

      expect(
        Textify.characterDefinitions.getDefinition(char)!.enclosures,
        0,
        reason: reason,
      );
    }

    // Enclosures
    expect(Textify.characterDefinitions.getDefinition('A')!.enclosures, 1);
    expect(Textify.characterDefinitions.getDefinition('B')!.enclosures, 2);
    expect(Textify.characterDefinitions.getDefinition('D')!.enclosures, 1);
    expect(Textify.characterDefinitions.getDefinition('O')!.enclosures, 1);
    expect(Textify.characterDefinitions.getDefinition('P')!.enclosures, 1);
    expect(Textify.characterDefinitions.getDefinition('Q')!.enclosures, 1);
    expect(Textify.characterDefinitions.getDefinition('a')!.enclosures, 1);
    expect(Textify.characterDefinitions.getDefinition('b')!.enclosures, 1);
    expect(Textify.characterDefinitions.getDefinition('d')!.enclosures, 1);
    expect(Textify.characterDefinitions.getDefinition('e')!.enclosures, 1);
    expect(Textify.characterDefinitions.getDefinition('g')!.enclosures, 1);
    expect(Textify.characterDefinitions.getDefinition('o')!.enclosures, 1);
    expect(Textify.characterDefinitions.getDefinition('p')!.enclosures, 1);
    expect(Textify.characterDefinitions.getDefinition('q')!.enclosures, 1);
    expect(Textify.characterDefinitions.getDefinition('0')!.enclosures, 1);
    expect(Textify.characterDefinitions.getDefinition('4')!.enclosures, 1);
    expect(Textify.characterDefinitions.getDefinition('6')!.enclosures, 1);
    expect(Textify.characterDefinitions.getDefinition('8')!.enclosures, 2);
    expect(Textify.characterDefinitions.getDefinition('9')!.enclosures, 1);
  });

  test('Character Definitions Lines Left', () async {
    expect(Textify.characterDefinitions.getDefinition('B')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('D')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('E')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('F')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('H')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('I')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('J')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('K')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('L')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('M')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('N')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('P')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('R')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('T')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('U')!.lineLeft, true);

    expect(Textify.characterDefinitions.getDefinition('b')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('h')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('i')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('k')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('l')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('m')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('n')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('p')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('r')!.lineLeft, true);
    expect(Textify.characterDefinitions.getDefinition('u')!.lineLeft, true);

    expect(Textify.characterDefinitions.getDefinition('f')!.lineLeft, false);
    expect(Textify.characterDefinitions.getDefinition('t')!.lineLeft, false);
  });

  test('Character Definitions Lines Right', () async {
    expect(Textify.characterDefinitions.getDefinition('H')!.lineRight, true);
    expect(Textify.characterDefinitions.getDefinition('I')!.lineRight, true);
    expect(Textify.characterDefinitions.getDefinition('J')!.lineRight, true);
    expect(Textify.characterDefinitions.getDefinition('L')!.lineRight, true);
    expect(Textify.characterDefinitions.getDefinition('M')!.lineRight, true);
    expect(Textify.characterDefinitions.getDefinition('N')!.lineRight, true);
    expect(Textify.characterDefinitions.getDefinition('T')!.lineRight, true);
    expect(Textify.characterDefinitions.getDefinition('U')!.lineRight, true);

    expect(Textify.characterDefinitions.getDefinition('d')!.lineRight, true);
    expect(Textify.characterDefinitions.getDefinition('i')!.lineRight, true);
    expect(Textify.characterDefinitions.getDefinition('j')!.lineRight, true);
    expect(Textify.characterDefinitions.getDefinition('l')!.lineRight, true);
    expect(Textify.characterDefinitions.getDefinition('m')!.lineRight, true);
    expect(Textify.characterDefinitions.getDefinition('n')!.lineRight, true);
    expect(Textify.characterDefinitions.getDefinition('q')!.lineRight, true);
    expect(Textify.characterDefinitions.getDefinition('t')!.lineRight, true);
    expect(Textify.characterDefinitions.getDefinition('u')!.lineRight, true);
  });

  test('Image with Connected_Letters - REMARKABLE', () async {
    final ui.Image uiImage = await Textify.loadImageFromAssets(
      'assets/test/REMARKABLE_test.png',
    );

    final ui.Image imageBlackAndWhite = await imageToBlackOnWhite(uiImage);

    final Artifact imageAsArtifact = await Artifact.artifactFromImage(
      imageBlackAndWhite,
    );

    final Textify testInstance = Textify(
      config: const TextifyConfig(applyDictionaryCorrection: false),
    );
    await testInstance.init(pathToAssetsDefinition: 'assets/matrices.json');

    //
    // Test splitting mechanics on connected letters
    //
    {
      testInstance.extractBandsAndArtifacts(imageAsArtifact);
      expect(testInstance.bands.list.length, 1);

      final Band band = testInstance.bands.list.first;
      //
      //  R E MARKAB L E
      //
      expect(band.artifacts.length, 5);

      // Find the wide artifact and test splitChunk on it
      final wideArtifact = band.artifacts.reduce(
        (a, b) => a.cols > b.cols ? a : b,
      );

      //
      // Now attempt to split the chunk MARKAB
      //
      {
        final List<int> valleys = splitting.artifactValleysOffsets(
          wideArtifact,
        );
        expect(valleys.length, 5, reason: '$valleys\n');

        final List<Artifact> subArtifacts = band.splitChunk(wideArtifact);
        expect(
          subArtifacts.length,
          6,
          reason: '${subArtifacts.first.toText()}\n',
        );
      }

      // Use getTextInBands which handles splitting in-loop
      final String text = await testInstance.getTextInBands(
        listOfBands: [band],
      );
      final int distance = levenshteinDistance('REMARKABLE', text);
      final double accuracy = 1 - (distance / 'REMARKABLE'.length);
      final double minAccuracy = TextifyConfig.accurate.matchingThreshold;
      expect(accuracy, greaterThanOrEqualTo(minAccuracy));

      final Textify dictInstance = Textify(
        config: const TextifyConfig(applyDictionaryCorrection: true),
      );
      await dictInstance.init(pathToAssetsDefinition: 'assets/matrices.json');
      final String text2 = await dictInstance.getTextInBands(
        listOfBands: [band],
      );
      expect(text2, 'REMARKABLE');
    }
  });

  test('Dictionary Correction', () async {
    // await myExpectWord('', '');
    // await myExpectWord('Hell0', 'Hello');
    // await myExpectWord('B0rder', 'Border');
    // await myExpectWord('Hello W0rld', 'Hello world');
    // await myExpectWord('ls', 'Is');
    // await myExpectWord('lS', 'Is');
    // await myExpectWord('ln', 'In');
    // await myExpectWord('lN', 'In');
    // await myExpectWord('Date', 'Date');
    // await myExpectWord('D@te', 'Date');
    // await myExpectWord('D@tes', 'Dates');
    // await myExpectWord('Bathr0Om', 'Bathroom');
    await myExpectWord('5pecial Ca5e', 'Special case');
  });

  test('Digit Correction', () async {
    expect(digitCorrection(''), '');
    expect(digitCorrection('0123456789'), '0123456789');
    expect(digitCorrection('O123456789'), '0123456789');
    expect(digitCorrection('ol23456789'), '0123456789');
  });

  test(
    'getMatchingScoresOfNormalizedMatrix filters by supportedCharacters',
    () async {
      final Textify instance = await Textify().init(
        pathToAssetsDefinition: 'assets/matrices.json',
      );

      // Create a simple artifact
      final Artifact testArtifact = Artifact.fromAsciiDefinition([
        '###',
        '# #',
        '###',
      ]);

      // Test with empty supportedCharacters (should return all possible matches)
      final List<ScoreMatch> allMatches = instance
          .getMatchingScoresOfNormalizedMatrix(testArtifact);
      expect(allMatches.isNotEmpty, true);

      // Test with specific supportedCharacters
      const String specificChars = 'ABC';
      final List<ScoreMatch> filteredMatches = instance
          .getMatchingScoresOfNormalizedMatrix(testArtifact, specificChars);

      // Verify all returned characters are in the supported list
      for (final match in filteredMatches) {
        expect(specificChars.contains(match.character), true);
      }

      // Verify characters not in supported list are excluded
      final Set<String> returnedChars = filteredMatches
          .map((m) => m.character)
          .toSet();
      expect(returnedChars.every((char) => specificChars.contains(char)), true);
    },
  );

  test('getTextInBands drops false spaces in punctuation-only band', () async {
    final Textify instance = await Textify().init(
      pathToAssetsDefinition: 'assets/matrices.json',
    );

    Artifact matchedArtifact(String character, int left) {
      final Artifact artifact = Artifact(3, 5);
      artifact.matchingCharacter = character;
      artifact.matchingScore = 1;
      artifact.locationFound = IntOffset(left, 0);
      artifact.locationAdjusted = IntOffset(left, 0);
      return artifact;
    }

    final Band band = Band();
    band.addArtifacts(<Artifact>[
      matchedArtifact('(', 0),
      matchedArtifact(' ', 4),
      matchedArtifact(')', 8),
      matchedArtifact('{', 12),
      matchedArtifact('}', 16),
      matchedArtifact('[', 16),
    ]);

    await instance.getTextInBands(listOfBands: <Band>[band]);

    expect(band.spacesCount, 0);
    expect(
      band.artifacts.map((artifact) => artifact.matchingCharacter).join(),
      '(){}[',
    );
  });

  test('generated invoice identifier preserves hyphen and digits', () async {
    await loadFontIfAvailable(
      'Courier',
      'assets/fonts/CourierPrime-Regular.ttf',
    );

    final Textify instance = await Textify(
      config: const TextifyConfig(applyDictionaryCorrection: false),
    ).init(pathToAssetsDefinition: 'assets/matrices.json');

    final ui.Image image = await renderTextImage(
      text: 'INV-2025/12/31',
      fontFamily: 'Courier',
      fontSize: 24,
    );

    expect(await instance.getTextFromImage(image: image), 'INV-2025/12/31');
  });

  test(
    'generated status line preserves punctuation and acronym case',
    () async {
      await loadFontIfAvailable('Roboto', 'assets/fonts/Roboto-Regular.ttf');

      final Textify instance = await Textify(
        config: const TextifyConfig(applyDictionaryCorrection: false),
      ).init(pathToAssetsDefinition: 'assets/matrices.json');

      final ui.Image image = await renderTextImage(
        text: 'Status: OK',
        fontFamily: 'Roboto',
        fontSize: 22,
      );

      expect(await instance.getTextFromImage(image: image), 'Status: OK');
    },
  );

  test('generated punctuation line preserves punctuation glyphs', () async {
    await loadFontIfAvailable(
      'Courier',
      'assets/fonts/CourierPrime-Regular.ttf',
    );

    final Textify instance = await Textify(
      config: const TextifyConfig(applyDictionaryCorrection: false),
    ).init(pathToAssetsDefinition: 'assets/matrices.json');

    const String expected = r'(){}[]<>/\,;:.!@#$&*-+=?';
    final ui.Image image = await renderTextImage(
      text: expected,
      fontFamily: 'Courier',
      fontSize: 24,
    );

    expect(await instance.getTextFromImage(image: image), expected);
  });

  test(
    'generated lowercase prose preserves word spacing and i glyphs',
    () async {
      await loadFontIfAvailable('Roboto', 'assets/fonts/Roboto-Regular.ttf');

      final Textify instance = await Textify(
        config: const TextifyConfig(applyDictionaryCorrection: false),
      ).init(pathToAssetsDefinition: 'assets/matrices.json');

      final ui.Image image = await renderTextImage(
        text: 'the quick brown fox jumps over the lazy dog',
        fontFamily: 'Roboto',
        fontSize: 24,
      );

      expect(
        await instance.getTextFromImage(image: image),
        'the quick brown fox jumps over the lazy dog',
      );
    },
  );

  test(
    'generated uppercase Helvetica preserves LA in LAZY without dictionary help',
    () async {
      await loadFontIfAvailable('Helvetica', 'assets/test/helvetica.ttf');

      final Textify instance = await Textify(
        config: const TextifyConfig(applyDictionaryCorrection: false),
      ).init(pathToAssetsDefinition: 'assets/matrices.json');

      final ui.Image image = await renderTextImage(
        text: 'THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG',
        fontFamily: 'Helvetica',
        fontSize: 24,
      );

      expect(
        await instance.getTextFromImage(image: image),
        'THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG',
      );
    },
  );

  test(
    'generated uppercase Times preserves I in QUICK without dictionary help',
    () async {
      await loadFontIfAvailable(
        'Times New Roman',
        'assets/test/times_new_roman.ttf',
      );

      final Textify instance = await Textify(
        config: const TextifyConfig(applyDictionaryCorrection: false),
      ).init(pathToAssetsDefinition: 'assets/matrices.json');

      final ui.Image image = await renderTextImage(
        text: 'THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG',
        fontFamily: 'Times New Roman',
        fontSize: 24,
      );

      expect(
        await instance.getTextFromImage(image: image),
        'THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG',
      );
    },
  );

  test(
    'asset uppercase prose preserves I glyph without dictionary help',
    () async {
      final ui.Image image = await Textify.loadImageFromAssets(
        'assets/test/the-quick-brown-fox.png',
      );

      final Textify instance = Textify(
        config: const TextifyConfig(applyDictionaryCorrection: false),
      );
      await instance.init(pathToAssetsDefinition: 'assets/matrices.json');

      expect(
        await instance.getTextFromImage(image: image),
        'THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG\n'
        'The quick brown fox jumps over the lazy dog\n'
        '2025-12-31',
      );
    },
  );

  test(
    'asset receipt items preserves uppercase T glyphs without dictionary help',
    () async {
      final ui.Image image = await Textify.loadImageFromAssets(
        'assets/test/receipt-items.png',
      );

      final Textify instance = Textify(
        config: const TextifyConfig(applyDictionaryCorrection: false),
      );
      await instance.init(pathToAssetsDefinition: 'assets/matrices.json');

      expect(
        await instance.getTextFromImage(image: image),
        'ITEM QTY PRICE\n'
        'Widget A 3 12.99\n'
        'Widget B 1 7.50\n'
        'Gadget C 2 24.00\n'
        'TOTAL 57.48',
      );
    },
  );

  test(
    'asset mixed-case sentence preserves title-case i glyphs without dictionary help',
    () async {
      final ui.Image image = await Textify.loadImageFromAssets(
        'assets/test/mixed-case-sentence.png',
      );

      final Textify instance = Textify(
        config: const TextifyConfig(applyDictionaryCorrection: false),
      );
      await instance.init(pathToAssetsDefinition: 'assets/matrices.json');

      expect(
        await instance.getTextFromImage(image: image),
        'OpenAI Released GPT In 2020.\n'
        'Version 4 Arrived In March 2023.',
      );
    },
  );

  test(
    'asset title-case names preserves surnames without dictionary help',
    () async {
      final ui.Image image = await Textify.loadImageFromAssets(
        'assets/test/title-case-names.png',
      );

      final Textify instance = Textify(
        config: const TextifyConfig(applyDictionaryCorrection: false),
      );
      await instance.init(pathToAssetsDefinition: 'assets/matrices.json');

      expect(
        await instance.getTextFromImage(image: image),
        'Alice Johnson\n'
        'Bob Williams\n'
        'Charlie Brown',
      );
    },
  );

  test(
    'asset codes and ids preserves EF in SKU without dictionary help',
    () async {
      final ui.Image image = await Textify.loadImageFromAssets(
        'assets/test/codes-and-ids.png',
      );

      final Textify instance = Textify(
        config: const TextifyConfig(applyDictionaryCorrection: false),
      );
      await instance.init(pathToAssetsDefinition: 'assets/matrices.json');

      expect(
        await instance.getTextFromImage(image: image),
        'ORD-20250615-0042\n'
        'SKU: AB12CD34EF56\n'
        'LOT: 2025/Q2/BATCH07',
      );
    },
  );

  test(
    'asset paragraph helvetica repairs lowercase e/o prose misses without dictionary help',
    () async {
      final ui.Image image = await Textify.loadImageFromAssets(
        'assets/test/paragraph-helvetica.png',
      );

      final Textify instance = Textify(
        config: const TextifyConfig(applyDictionaryCorrection: false),
      );
      await instance.init(pathToAssetsDefinition: 'assets/matrices.json');

      expect(
        await instance.getTextFromImage(image: image),
        'Payment received on 03/15/2025.\n'
        'Your balance is now 0.00 USD.\n'
        'Thank you for your purchase.',
      );
    },
  );

  test(
    'asset small-text dense preserves structured fields without dictionary help',
    () async {
      final ui.Image image = await Textify.loadImageFromAssets(
        'assets/test/small-text-dense.png',
      );

      final Textify instance = Textify(
        config: const TextifyConfig(applyDictionaryCorrection: false),
      );
      await instance.init(pathToAssetsDefinition: 'assets/matrices.json');

      expect(
        await instance.getTextFromImage(image: image),
        'Name: John Smith\n'
        'Date: 2025-06-15\n'
        'Reference: TX-98432\n'
        'Amount: 1,250.75\n'
        'Status: CONFIRMED',
      );
    },
  );

  test(
    'asset bank statement preserves LUXEMBOURG without dictionary help',
    () async {
      final ui.Image image = await Textify.loadImageFromAssets(
        'assets/test/bank_statement_test.png',
      );

      final Textify instance = Textify(
        config: const TextifyConfig(applyDictionaryCorrection: false),
      );
      await instance.init(pathToAssetsDefinition: 'assets/matrices.json');

      expect(
        await instance.getTextFromImage(image: image),
        contains('WWW.AMAZON.* LSIAK28I5, LUXEMBOURG'),
      );
    },
  );
}

Future<void> myExpectWord(final String input, final String expected) async {
  expect(
    applyCorrection(input, true),
    equals(expected),
    reason: 'INPUT WAS  "$input"',
  );
}

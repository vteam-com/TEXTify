import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textify/band.dart';
import 'package:textify/character_definition.dart';
import 'package:textify/correction.dart';
import 'package:textify/models/score_match.dart';
import 'package:textify/textify.dart';
import 'package:textify/models/textify_config.dart';
import 'package:textify/image_helpers.dart';

void printMatrix(final Artifact matrix) {
  // ignore: avoid_print
  print(
    '${matrix.gridToString()}\n     L:${matrix.rectFound.left} T:${matrix.rectFound.top}  W:${matrix.cols} H:${matrix.rows}\n',
  );
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

  test('Convert image to text', () async {
    final ui.Image uiImage = await Textify.loadImageFromAssets(
      'assets/test/input_test_image.png',
    );
    final Textify testInstance = Textify(
      config: const TextifyConfig(applyDictionaryCorrection: false),
    );
    await testInstance.init(pathToAssetsDefinition: 'assets/matrices.json');
    final String text = await testInstance.getTextFromImage(image: uiImage);
    expect(testInstance.duration, greaterThan(0));

    // the result are not perfect 90% accuracy, but its trending in the right direction
    expect(testInstance.count, text.length);

    expect(
      text,
      'ABCDEFGHl\n'
      'JKLMNOPQR\n'
      'STUVWxYZ\n'
      '0123456789',
    );
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
      config: const TextifyConfig(
        applyDictionaryCorrection: false,
        attemptCharacterSplitting: false,
      ),
    );
    await testInstance.init(pathToAssetsDefinition: 'assets/matrices.json');

    //
    // First test withtout the [Inner-splitting]
    //
    {
      testInstance.extractBandsAndArtifacts(imageAsArtifact);
      expect(testInstance.bands.list.length, 1);

      final Band band = testInstance.bands.list.first;
      //
      //  R E MARKAB L E
      //
      expect(band.artifacts.length, 5);

      List<Artifact> suspectedChunks = band.getWideChunks();
      expect(suspectedChunks.length, 1);

      //
      // Now attempt to split the two chunks MAR & KAB
      //

      // Chunk MARKAB
      {
        final chunk1 = suspectedChunks[0];
        final List<int> valleys = Artifact.artifactValleysOffsets(chunk1);
        expect(valleys.length, 5, reason: '$valleys\n');

        final List<Artifact> subArtifactsOfChunk1 = band.splitChunk(chunk1);
        expect(
          subArtifactsOfChunk1.length,
          6,
          reason: '${subArtifactsOfChunk1.first.toText()}\n',
        );
      }

      band.identifySuspiciousLargeArtifacts();

      // for (final artifact in band.artifacts) {
      //   print('${artifact.toText()}\n');
      // }
      expect(band.artifacts.length, 10);

      void testExpectation(final Artifact artifact, final int expectedWidth) {
        expect(artifact.cols, expectedWidth, reason: '${artifact.toText()}\n');
      }

      // We know that 'R E' are not connected
      testExpectation(band.artifacts[00], 106); // R
      testExpectation(band.artifacts[01], 099); // E
      testExpectation(band.artifacts[02], 156); // M
      testExpectation(band.artifacts[03], 122); // A
      testExpectation(band.artifacts[04], 108); // R
      testExpectation(band.artifacts[05], 124); // K
      testExpectation(band.artifacts[06], 120); // A
      testExpectation(band.artifacts[07], 109); // B
      testExpectation(band.artifacts[08], 092); // L
      testExpectation(band.artifacts[09], 098); // E

      final String text = await testInstance.getTextInBands(
        listOfBands: [band],
      );
      expect(text, 'REMAPKAB[E'); // some comlexity with the space

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

  test('Convert image to text', () async {
    final ui.Image uiImage = await Textify.loadImageFromAssets(
      'assets/test/bank_statement_test.png',
    );
    final Textify bankInstance = Textify(
      config: const TextifyConfig(
        attemptCharacterSplitting: true,
        applyDictionaryCorrection: false,
      ),
    );
    await bankInstance.init(pathToAssetsDefinition: 'assets/matrices.json');
    final String text = await bankInstance.getTextFromImage(image: uiImage);

    // the result are not perfect 90% accuracy, but its trending in the right direction
    expect(
      text,
      'FINO GOLF CLUB, MATOSINHOS\n'
      'CONTINENTE BOM DIA, MATOSINHOS\n'
      'www.AMAZON.* LSlAK28IB, LUXEMBOURG\n'
      'REMAPKABLE, OSLO\n'
      'PINGO DOCE MATOSINHO, MATOSINHOS\n'
      'CONTINENTE BOM DIA, MATOSINHOS\n'
      'PAB PORT MATO, MATOSINHOS\n'
      'CASA DAS UTILIDABES, Guimaraes\n'
      'EUROLOJAMATOSINHOS, MATOSINHOS\n'
      'CORES SABORES BOLHAO, PORTO\n'
      'Tuca Cha E Cafe, PORTO',
    );
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
}

Future<void> myExpectWord(final String input, final String expected) async {
  expect(
    applyCorrection(input, true),
    equals(expected),
    reason: 'INPUT WAS  "$input"',
  );
}

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textify/bands.dart';
import 'package:textify/int_rect.dart';
import 'package:textify/textify.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/generate_samples/generate_image.dart';

Future<void> loadTestFont() async {
  // Load Roboto font
  final ByteData robotoFontData =
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  final FontLoader robotoFontLoader = FontLoader('Roboto')
    ..addFont(Future.value(robotoFontData));
  await robotoFontLoader.load();

  // Load Courier font
  final ByteData courierFontData =
      await rootBundle.load('assets/fonts/CourierPrime-Regular.ttf');
  final FontLoader courierFontLoader = FontLoader('Courier')
    ..addFont(Future.value(courierFontData));
  await courierFontLoader.load();
}

void printMatrix(final Artifact matrix, final bool printResult) {
  if (printResult) {
    // ignore: avoid_print
    print(
      '${matrix.gridToString()}\n     L:${matrix.rectFound.left} T:${matrix.rectFound.top}  W:${matrix.cols} H:${matrix.rows}\n',
    );
  }
}

void main() async {
  setUpAll(() async {
    await loadTestFont();
  });

  WidgetsFlutterBinding.ensureInitialized();

  final Textify textify = await Textify().init(
    pathToAssetsDefinition: 'assets/matrices.json',
  );
  textify.applyDictionary = true;

  group('Steps', () {
    test('Empty image', () async {
      final ui.Image uiImage = await generateImageDrawText(
        imageWidth: 1,
        imageHeight: 1,
        text: '',
        fontFamily: 'FontTest',
        fontSize: 20,
      );

      final String textResults = await textify.getTextFromImage(image: uiImage);
      expect(textResults, '');
    });

    final String inputText = 'Quip,\nWord me';

    test('One line text with Font: Courier', () async {
      await testWidthFont(
        textify: textify,
        text: inputText,
        result: 'Quit ,\n'
            'word we',
        fontFamily: 'Courier',
        imageWidth: 130,
        imageHeight: 60,
        finalExpectedRect: Rect.fromLTRB(11.0, 7.0, 52.0, 23.0),
        printResuls: false,
      );
    });

    test('One line text with Font: Roboto', () async {
      await testWidthFont(
        textify: textify,
        text: inputText,
        result: 'Quick\n'
            'WO[D WE',
        fontFamily: 'Roboto',
        imageWidth: 200,
        imageHeight: 60,
        finalExpectedRect: Rect.fromLTRB(11, 8, 126, 26),
        printResuls: false,
      );
    });

    test('Using image QuickBrownFox', () async {
      WidgetsFlutterBinding.ensureInitialized();

      final ui.Image image = await Textify.loadImageFromAssets(
        'assets/test/the-quick-brown-fox.png',
      );

      // Run test on a image
      await testFromImage(
        textify,
        image,
        'THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG\n'
        'The quick brown fox jumps over the lazy dog\n'
        '2025-12-31',
        printResuls: false,
        dilateFactor: 22,
      );
    });
  });
}

Future<void> testWidthFont({
  required final Textify textify,
  required final String text,
  required final String result,
  required final String fontFamily,
  required final int imageWidth,
  required final int imageHeight,
  required final Rect finalExpectedRect,
  required final bool printResuls,
}) async {
  final ui.Image image = await generateImageDrawText(
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    text: text,
    fontFamily: fontFamily,
    fontSize: 24,
    offset: Offset(10, 5),
  );

  // Run test on a image
  await testFromImage(
    textify,
    image,
    result,
    printResuls: printResuls,
  );
}

Future<void> testFromImage(
  final Textify textify,
  final ui.Image image,
  final String expectedText, {
  final printResuls = false,
  final int? dilateFactor,
  final bool innerSplit = false,
}) async {
  //
  // Black and White
  //
  final ui.Image imageBlackAndWhite = await imageToBlackOnWhite(image);
  expect(imageBlackAndWhite.width, image.width);
  expect(imageBlackAndWhite.height, image.height);

  //
  // To Matrix
  //
  final Artifact matrixSourceImage =
      await Artifact.fromImage(imageBlackAndWhite);
  expect(matrixSourceImage.cols, image.width);
  expect(matrixSourceImage.rows, image.height);
  printMatrix(matrixSourceImage, printResuls);

  //
  // Dilate
  //
  int kernelSize =
      dilateFactor ?? computeKernelSize(image.width, image.height, 0.02);

  final Artifact imageAsMatrixDilated = dilateMatrix(
    matrixImage: matrixSourceImage,
    kernelSize: kernelSize,
  );
  expect(imageAsMatrixDilated.cols, image.width);
  expect(imageAsMatrixDilated.rows, image.height);
  printMatrix(imageAsMatrixDilated, printResuls);

  //
  // Find the Artifacts in each regions
  //
  final List<IntRect> regions =
      findRegions(dilatedMatrixImage: imageAsMatrixDilated);

  Bands bands =
      Bands.getBandsOfArtifacts(matrixSourceImage, regions, innerSplit);

  final stringInAllBands1 = bands.getText();
  expect(stringInAllBands1.trim(), isEmpty);

  String resultingText = await textify.getTextFromArtifacts(
    listOfBands: bands.list,
  );
  final stringInAllBands2 = bands.getText();
  expect(stringInAllBands2, isNotEmpty);

  expect(resultingText, expectedText);
}

List<Band> testRegionToBand(
  Artifact matrixSourceImage,
  IntRect region,
  bool printResuls,
) {
  //
  // get the source image for the region
  //
  final Artifact regionMatrix = Artifact.extractSubGrid(
    matrix: matrixSourceImage,
    rect: region,
  );
  // printMatrix(regionMatrix);

  rowToBand(
    regionMatrix: matrixSourceImage,
    offset: region.topLeft,
  );

  // Split Region into Rows
  List<Band> bandsFoundInRegion = getBandsFromRegionRow(
    regionMatrix: regionMatrix,
  );

  // Print all charactes found
  bandsFoundInRegion.forEach((Band b) {
    b.artifacts.forEach((a) {
      printMatrix(a, printResuls);
    });
  });
  return bandsFoundInRegion;
}

List<Band> getBandsFromRegionRow({
  required final Artifact regionMatrix,
}) {
  // Split Region into Rows
  List<Artifact> regionAsRows = splitRegionIntoRows(regionMatrix);

  //
  // Find the Matrices in the Row
  //
  List<Band> bandsFoundInRegion = [];

  for (final Artifact regionRow in regionAsRows) {
    bandsFoundInRegion.add(
      rowToBand(
        regionMatrix: regionMatrix,
        offset: regionRow.rectFound.topLeft,
      ),
    );
  }
  return bandsFoundInRegion;
}

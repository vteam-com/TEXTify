import 'dart:io' show Platform, stderr;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textify/textify.dart';
import 'package:textify/models/textify_config.dart';

class EvalCase {
  const EvalCase({
    required this.name,
    required this.text,
    required this.fontFamily,
    required this.fontSize,
    this.padding = 12,
  });

  final String name;
  final String text;
  final String fontFamily;
  final double fontSize;
  final int padding;
}

class AssetEvalCase {
  const AssetEvalCase({
    required this.name,
    required this.assetPath,
    required this.expectedText,
    this.splitting = false,
  });

  final String name;
  final String assetPath;
  final String expectedText;
  final bool splitting;
}

Future<void> _loadFontIfAvailable(String family, String assetPath) async {
  try {
    final ByteData fontData = await rootBundle.load(assetPath);
    final FontLoader loader = FontLoader(family)
      ..addFont(Future.value(fontData));
    await loader.load();
  } catch (_) {
    // Font not available in assets; fallback to system font if present.
  }
}

Future<void> _loadTestFonts() async {
  await _loadFontIfAvailable('Roboto', 'assets/fonts/Roboto-Regular.ttf');
  await _loadFontIfAvailable(
    'Courier',
    'assets/fonts/CourierPrime-Regular.ttf',
  );
  await _loadFontIfAvailable('Helvetica', 'assets/test/helvetica.ttf');
  await _loadFontIfAvailable('Arial', 'assets/test/arial.ttf');
  await _loadFontIfAvailable(
    'Times New Roman',
    'assets/test/times_new_roman.ttf',
  );
}

Future<ui.Image> _renderTextImage({
  required String text,
  required String fontFamily,
  required double fontSize,
  int padding = 12,
}) async {
  final TextPainter textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.black,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        fontFamily: fontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final int width = max(1, textPainter.width.ceil() + (padding * 2));
  final int height = max(1, textPainter.height.ceil() + (padding * 2));

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);

  final ui.Paint paint = ui.Paint()..color = Colors.white;
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    paint,
  );

  textPainter.paint(canvas, Offset(padding.toDouble(), padding.toDouble()));

  final ui.Picture picture = recorder.endRecording();
  return picture.toImage(width, height);
}

int _levenshteinDistance(String a, String b) {
  if (a == b) {
    return 0;
  }
  if (a.isEmpty) {
    return b.length;
  }
  if (b.isEmpty) {
    return a.length;
  }

  final int m = a.length;
  final int n = b.length;
  List<int> previous = List<int>.generate(n + 1, (int j) => j);
  List<int> current = List<int>.filled(n + 1, 0);

  for (int i = 1; i <= m; i++) {
    current[0] = i;
    final int aCode = a.codeUnitAt(i - 1);
    for (int j = 1; j <= n; j++) {
      final int bCode = b.codeUnitAt(j - 1);
      final int cost = aCode == bCode ? 0 : 1;
      final int deletion = previous[j] + 1;
      final int insertion = current[j - 1] + 1;
      final int substitution = previous[j - 1] + cost;
      current[j] = min(deletion, min(insertion, substitution));
    }
    final List<int> swap = previous;
    previous = current;
    current = swap;
  }

  return previous[n];
}

String _escapeVisible(String value) {
  return value.replaceAll('\n', r'\n');
}

String _shorten(String value, {int maxLen = 120}) {
  if (value.length <= maxLen) {
    return value;
  }
  return '${value.substring(0, maxLen - 3)}...';
}

bool _readVerboseEval() {
  final String? raw = Platform.environment['TEXTIFY_TEST_VERBOSE'];
  if (raw == null) {
    return false;
  }
  final String normalized = raw.trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

final bool _verboseEval = _readVerboseEval();

void _logEval(String message) {
  if (_verboseEval) {
    // ignore: avoid_print
    print(message);
    return;
  }
  printOnFailure(message);
}

class _Score {
  int expectedChars = 0;
  int distance = 0;
  int bands = 0;
  int artifacts = 0;
  int images = 0;

  double get accuracy =>
      expectedChars == 0 ? 0.0 : 1.0 - (distance / expectedChars);

  void add(_Score other) {
    expectedChars += other.expectedChars;
    distance += other.distance;
    bands += other.bands;
    artifacts += other.artifacts;
    images += other.images;
  }

  void record(Textify textify, String expected, String actual) {
    images++;
    expectedChars += expected.length;
    distance += _levenshteinDistance(expected, actual);
    bands += textify.bands.length;
    artifacts += textify.bands.totalArtifacts;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadTestFonts();
  });

  const TextifyConfig evalConfig = TextifyConfig(
    applyDictionaryCorrection: false,
  );

  final List<EvalCase> cases = <EvalCase>[
    const EvalCase(
      name: 'upper-alpha',
      text: 'THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG',
      fontFamily: 'Roboto',
      fontSize: 24,
    ),
    const EvalCase(
      name: 'upper-alpha-helvetica',
      text: 'THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG',
      fontFamily: 'Helvetica',
      fontSize: 24,
    ),
    const EvalCase(
      name: 'upper-alpha-arial',
      text: 'THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG',
      fontFamily: 'Arial',
      fontSize: 24,
    ),
    const EvalCase(
      name: 'upper-alpha-times',
      text: 'THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG',
      fontFamily: 'Times New Roman',
      fontSize: 24,
    ),
    const EvalCase(
      name: 'lower-alpha',
      text: 'the quick brown fox jumps over the lazy dog',
      fontFamily: 'Roboto',
      fontSize: 24,
    ),
    const EvalCase(
      name: 'digits',
      text: '0123456789',
      fontFamily: 'Courier',
      fontSize: 24,
    ),
    const EvalCase(
      name: 'mixed-1',
      text: 'INV-2025/12/31',
      fontFamily: 'Courier',
      fontSize: 24,
    ),
    const EvalCase(
      name: 'punctuation',
      text: r'(){}[]<>/\,;:.!@#$&*-+=?',
      fontFamily: 'Courier',
      fontSize: 24,
    ),
    const EvalCase(
      name: 'multi-line',
      text: 'Order: 12345\nTotal: 67.89\nStatus: OK',
      fontFamily: 'Roboto',
      fontSize: 22,
    ),
  ];

  final List<AssetEvalCase> assetCases = <AssetEvalCase>[
    const AssetEvalCase(
      name: 'input_test_image',
      assetPath: 'assets/test/input_test_image.png',
      expectedText:
          'ABCDEFGHI\n'
          'JKLMNOPQR\n'
          'STUVWXYZ 0123456789',
    ),
    const AssetEvalCase(
      name: 'the-quick-brown-fox',
      assetPath: 'assets/test/the-quick-brown-fox.png',
      expectedText:
          'THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG\n'
          'The quick brown fox jumps over the lazy dog\n'
          '2025-12-31',
    ),
    const AssetEvalCase(
      name: 'lines-circles',
      assetPath: 'assets/test/lines-circles.png',
      splitting: true,
      expectedText:
          'HELLO THIS IS A TEST IN UPPER CASE.\n'
          'This is a normal phrase with number like 123,456.89\n'
          'DATES\n'
          '2020-01-02\n'
          '2021/03/04\n'
          '2022.05.05\n'
          'The\n'
          'End',
    ),
    const AssetEvalCase(
      name: 'bank_statement',
      assetPath: 'assets/test/bank_statement_test.png',
      splitting: true,
      expectedText:
          'FINO GOLF CLUB, MATOSINHOS\n'
          'CONTINENTE BOM DIA, MATOSINHOS\n'
          'www.AMAZON.* LSIAK28I5, LUXEMBOURG\n'
          'REMARKABLE, OSLO\n'
          'PINGO DOCE MATOSINHOS, MATOSINHOS\n'
          'CONTINENTE BOM DIA, MATOSINHOS\n'
          'PAD PORT MATO, MATOSINHOS\n'
          'CASA DAS UTILIDADES, Guimaraes\n'
          'EUROLOJA MATOSINHOS, MATOSINHOS\n'
          'CORES SABORES BOLHAO, PORTO\n'
          'Tuca Cha E Cafe, PORTO',
    ),
    const AssetEvalCase(
      name: 'REMARKABLE',
      assetPath: 'assets/test/REMARKABLE_test.png',
      splitting: true,
      expectedText: 'REMARKABLE',
    ),
    // --- 10 generated test images ---
    const AssetEvalCase(
      name: 'address-block',
      assetPath: 'assets/test/address-block.png',
      expectedText:
          '350 MAIN STREET\n'
          'SAN FRANCISCO, CA 94105\n'
          'UNITED STATES',
    ),
    const AssetEvalCase(
      name: 'receipt-items',
      assetPath: 'assets/test/receipt-items.png',
      expectedText:
          'ITEM QTY PRICE\n'
          'Widget A 3 12.99\n'
          'Widget B 1 7.50\n'
          'Gadget C 2 24.00\n'
          'TOTAL 57.48',
    ),
    const AssetEvalCase(
      name: 'mixed-case-sentence',
      assetPath: 'assets/test/mixed-case-sentence.png',
      expectedText:
          'OpenAI Released GPT In 2020.\n'
          'Version 4 Arrived In March 2023.',
    ),
    const AssetEvalCase(
      name: 'single-line-large',
      assetPath: 'assets/test/single-line-large.png',
      expectedText: 'WAREHOUSE PICKUP 9AM',
    ),
    const AssetEvalCase(
      name: 'numbers-grid',
      assetPath: 'assets/test/numbers-grid.png',
      expectedText:
          '1001 2002 3003\n'
          '4004 5005 6006\n'
          '7007 8008 9009',
    ),
    const AssetEvalCase(
      name: 'small-text-dense',
      assetPath: 'assets/test/small-text-dense.png',
      expectedText:
          'Name: John Smith\n'
          'Date: 2025-06-15\n'
          'Reference: TX-98432\n'
          'Amount: 1,250.75\n'
          'Status: CONFIRMED',
    ),
    const AssetEvalCase(
      name: 'uppercase-short-words',
      assetPath: 'assets/test/uppercase-short-words.png',
      expectedText:
          'GO BIG OR GO HOME\n'
          'BE THE BEST YOU CAN BE',
    ),
    const AssetEvalCase(
      name: 'title-case-names',
      assetPath: 'assets/test/title-case-names.png',
      expectedText:
          'Alice Johnson\n'
          'Bob Williams\n'
          'Charlie Brown',
    ),
    const AssetEvalCase(
      name: 'codes-and-ids',
      assetPath: 'assets/test/codes-and-ids.png',
      expectedText:
          'ORD-20250615-0042\n'
          'SKU: AB12CD34EF56\n'
          'LOT: 2025/Q2/BATCH07',
    ),
    const AssetEvalCase(
      name: 'paragraph-helvetica',
      assetPath: 'assets/test/paragraph-helvetica.png',
      expectedText:
          'Payment received on 03/15/2025.\n'
          'Your balance is now 0.00 USD.\n'
          'Thank you for your purchase.',
    ),
  ];

  test('OCR evaluation (baseline)', () async {
    final Textify textify = await Textify(
      config: evalConfig,
    ).init(pathToAssetsDefinition: 'assets/matrices.json');

    final _Score generatedScore = _Score();
    final _Score assetScore = _Score();
    final Stopwatch totalStopwatch = Stopwatch()..start();

    _logEval('--- Generated images ---');

    for (final EvalCase evalCase in cases) {
      final ui.Image image = await _renderTextImage(
        text: evalCase.text,
        fontFamily: evalCase.fontFamily,
        fontSize: evalCase.fontSize,
        padding: evalCase.padding,
      );

      final Stopwatch sw = Stopwatch()..start();
      final String actualText = await textify.getTextFromImage(image: image);
      sw.stop();

      generatedScore.record(textify, evalCase.text, actualText);

      final String exactLabel = evalCase.text == actualText ? 'yes' : 'no';

      _logEval(
        '${evalCase.name} | font:${evalCase.fontFamily} ${evalCase.fontSize.toInt()}px '
        '| expected:${evalCase.text.length} actual:${actualText.length} '
        '| char-acc:${((1.0 - (_levenshteinDistance(evalCase.text, actualText) / evalCase.text.length)) * 100).toStringAsFixed(2)}% '
        '| exact:$exactLabel'
        '| ${sw.elapsedMilliseconds}ms',
      );

      if (evalCase.text != actualText) {
        _logEval('  expected: "${_shorten(_escapeVisible(evalCase.text))}"');
        _logEval('  actual:   "${_shorten(_escapeVisible(actualText))}"');
      }
    }

    _logEval('--- Asset images ---');
    for (final AssetEvalCase assetCase in assetCases) {
      final ui.Image image = await Textify.loadImageFromAssets(
        assetCase.assetPath,
      );

      final Textify assetTextify = Textify(
        config: TextifyConfig(
          applyDictionaryCorrection: false,
          attemptCharacterSplitting: assetCase.splitting,
        ),
      );
      await assetTextify.init(pathToAssetsDefinition: 'assets/matrices.json');

      final Stopwatch sw = Stopwatch()..start();
      final String actualText = await assetTextify.getTextFromImage(
        image: image,
      );
      sw.stop();

      assetScore.record(assetTextify, assetCase.expectedText, actualText);

      final String exactLabel = assetCase.expectedText == actualText
          ? 'yes'
          : 'no';

      _logEval(
        '${assetCase.name} | asset'
        ' | expected:${assetCase.expectedText.length} actual:${actualText.length}'
        ' | char-acc:${((1.0 - (_levenshteinDistance(assetCase.expectedText, actualText) / assetCase.expectedText.length)) * 100).toStringAsFixed(2)}%'
        ' | exact:$exactLabel'
        ' | ${sw.elapsedMilliseconds}ms',
      );

      if (assetCase.expectedText != actualText) {
        _logEval(
          '  expected: "${_shorten(_escapeVisible(assetCase.expectedText))}"',
        );
        _logEval('  actual:   "${_shorten(_escapeVisible(actualText))}"');
      }
    }

    totalStopwatch.stop();

    final _Score total = _Score()
      ..add(generatedScore)
      ..add(assetScore);

    _logEval('---');
    _logEval(
      'Generated: accuracy=${(generatedScore.accuracy * 100).toStringAsFixed(2)}%',
    );
    _logEval(
      'Assets:    accuracy=${(assetScore.accuracy * 100).toStringAsFixed(2)}%',
    );
    _logEval(
      'Overall:   accuracy=${(total.accuracy * 100).toStringAsFixed(2)}%',
    );
    _logEval('Total time: ${totalStopwatch.elapsedMilliseconds}ms');

    // Always print summary so it's visible in normal test runs
    stderr.writeln(
      'OCR eval:'
      ' generated=${(generatedScore.accuracy * 100).toStringAsFixed(1)}%'
      ' assets=${(assetScore.accuracy * 100).toStringAsFixed(1)}%'
      ' overall=${(total.accuracy * 100).toStringAsFixed(1)}%'
      ' | images=${total.images}'
      ' bands=${total.bands}'
      ' artifacts=${total.artifacts}'
      ' chars=${total.expectedChars}'
      ' | ${totalStopwatch.elapsedMilliseconds}ms',
    );
  });
}

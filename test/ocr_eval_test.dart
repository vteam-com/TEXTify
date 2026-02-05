import 'dart:io' show Platform;
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

  test('OCR evaluation (baseline)', () async {
    final Textify textify = await Textify(
      config: evalConfig,
    ).init(pathToAssetsDefinition: 'assets/matrices.json');

    int totalExpectedChars = 0;
    int totalDistance = 0;
    int exactMatches = 0;

    _logEval('OCR Evaluation');
    _logEval('Config: $evalConfig');
    _logEval('Cases: ${cases.length}');
    _logEval('---');

    for (final EvalCase evalCase in cases) {
      final ui.Image image = await _renderTextImage(
        text: evalCase.text,
        fontFamily: evalCase.fontFamily,
        fontSize: evalCase.fontSize,
        padding: evalCase.padding,
      );

      final String actualText = await textify.getTextFromImage(image: image);
      final String expectedText = evalCase.text;

      final int distance = _levenshteinDistance(expectedText, actualText);
      final int expectedLen = expectedText.length;
      final int actualLen = actualText.length;
      final double charAccuracy = expectedLen == 0
          ? (actualLen == 0 ? 1.0 : 0.0)
          : 1.0 - (distance / expectedLen);

      totalExpectedChars += expectedLen;
      totalDistance += distance;
      if (expectedText == actualText) {
        exactMatches++;
      }

      final String expectedPreview = _shorten(_escapeVisible(expectedText));
      final String actualPreview = _shorten(_escapeVisible(actualText));
      final String exactLabel = expectedText == actualText ? 'yes' : 'no';

      _logEval(
        '${evalCase.name} | font:${evalCase.fontFamily} ${evalCase.fontSize.toInt()}px '
        '| expected:$expectedLen actual:$actualLen '
        '| char-acc:${(charAccuracy * 100).toStringAsFixed(2)}% '
        '| exact:$exactLabel',
      );

      if (expectedText != actualText) {
        _logEval('  expected: "$expectedPreview"');
        _logEval('  actual:   "$actualPreview"');
      }
    }

    final double overallCharAccuracy = totalExpectedChars == 0
        ? 0.0
        : 1.0 - (totalDistance / totalExpectedChars);
    final double exactRate = cases.isEmpty ? 0.0 : exactMatches / cases.length;

    _logEval('---');
    _logEval(
      'Overall char-accuracy: ${(overallCharAccuracy * 100).toStringAsFixed(2)}%',
    );
    _logEval('Exact-match rate: ${(exactRate * 100).toStringAsFixed(2)}%');
  });
}

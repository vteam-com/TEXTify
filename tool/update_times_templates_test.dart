import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textify/artifact.dart';
import 'package:textify/character_definitions.dart';
import 'package:textify/image_helpers.dart';
import 'package:textify/textify.dart';

const String _fontFamily = 'Times New Roman';
const String _fontAssetPath = 'assets/test/times_new_roman.ttf';
const int _templateImageWidth = 40 * 6;
const int _templateImageHeight = 60;
const int _templateFontSize = 40;

Future<void> _loadFont() async {
  final ByteData fontData = await rootBundle.load(_fontAssetPath);
  final FontLoader loader = FontLoader(_fontFamily)
    ..addFont(Future.value(fontData));
  await loader.load();
}

Future<ui.Image> _renderTemplateImage(String text) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);

  final ui.Paint paint = ui.Paint()..color = Colors.white;
  canvas.drawRect(
    ui.Rect.fromLTWH(
      0,
      0,
      _templateImageWidth.toDouble(),
      _templateImageHeight.toDouble(),
    ),
    paint,
  );

  final TextPainter textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.black,
        fontSize: _templateFontSize.toDouble(),
        fontWeight: FontWeight.bold,
        fontFamily: _fontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  textPainter.paint(canvas, const Offset(0, 0));

  final ui.Picture picture = recorder.endRecording();
  return picture.toImage(_templateImageWidth, _templateImageHeight);
}

Future<void> _updateTemplateForChar(Textify textify, String char) async {
  final ui.Image image = await _renderTemplateImage('A $char W');
  final ui.Image imageOptimized = await imageToBlackOnWhite(image);
  final Artifact imageAsMatrix = await Artifact.artifactFromImage(
    imageOptimized,
  );

  textify.extractBandsAndArtifacts(imageAsMatrix);

  if (textify.bands.length != 1) {
    return;
  }

  final List<Artifact> artifacts = textify.bands.list.first.artifacts
      .where((Artifact artifact) => artifact.isNotEmpty)
      .toList();

  if (artifacts.length != 3) {
    return;
  }

  final Artifact targetArtifact = artifacts[1];
  final Artifact matrix = targetArtifact.createNormalizeMatrix(
    CharacterDefinition.templateWidth,
    CharacterDefinition.templateHeight,
  );

  if (matrix.isEmpty) {
    return;
  }

  Textify.characterDefinitions.upsertTemplate(_fontFamily, char, matrix);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Update Times New Roman uppercase templates',
    () async {
      await _loadFont();

      final Textify textify = await Textify().init(
        pathToAssetsDefinition: 'assets/matrices.json',
      );

      for (final String char in letterUpperCase) {
        await _updateTemplateForChar(textify, char);
      }

      final File outFile = File('assets/matrices.json');
      await outFile.writeAsString(Textify.characterDefinitions.toJsonString());
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

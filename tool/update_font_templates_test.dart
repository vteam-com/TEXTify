/// Tool to regenerate character templates for embedded fonts at the test render
/// size (24 px bold). Run with:
///
///   flutter test tool/update_font_templates_test.dart
///
/// This overwrites assets/matrices.json with updated templates for Arial,
/// Helvetica, and Times New Roman at 24 px bold — the same size and weight
/// used by the OCR-eval generated-image tests.
///
/// The existing 40 px templates produced by update_times_templates_test.dart
/// are replaced for these three fonts. The 24 px normalization produces
/// more accurate patterns at the test render size.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textify/artifact.dart';
import 'package:textify/artifact_grid_transform.dart';
import 'package:textify/character_definitions.dart';
import 'package:textify/image_helpers.dart';
import 'package:textify/textify.dart';

// Use the same font size as the generated-image eval tests.
const int _templateFontSize = 24;

// Render canvas: wide enough for "A X W" at 24 px with padding.
const int _templateImageWidth = _templateFontSize * 6;
const int _templateImageHeight = _templateFontSize * 3;

const List<({String family, String assetPath})> _fonts = [
  (family: 'Arial', assetPath: 'assets/test/arial.ttf'),
  (family: 'Helvetica', assetPath: 'assets/test/helvetica.ttf'),
  (family: 'Times New Roman', assetPath: 'assets/test/times_new_roman.ttf'),
];

Future<void> _loadFont(String family, String assetPath) async {
  final ByteData fontData = await rootBundle.load(assetPath);
  final FontLoader loader = FontLoader(family)..addFont(Future.value(fontData));
  await loader.load();
}

Future<ui.Image> _renderTemplateImage(String text, String fontFamily) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);

  final ui.Paint bg = ui.Paint()..color = Colors.white;
  canvas.drawRect(
    ui.Rect.fromLTWH(
      0,
      0,
      _templateImageWidth.toDouble(),
      _templateImageHeight.toDouble(),
    ),
    bg,
  );

  final TextPainter textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.black,
        fontSize: _templateFontSize.toDouble(),
        fontWeight: FontWeight.bold,
        fontFamily: fontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  textPainter.paint(canvas, const Offset(4, 4));

  final ui.Picture picture = recorder.endRecording();
  return picture.toImage(_templateImageWidth, _templateImageHeight);
}

/// Renders "A [char] W", extracts the middle artifact, normalizes it, and
/// upserts it into the template database for [fontFamily].
Future<void> _updateTemplateForChar(
  Textify textify,
  String fontFamily,
  String char,
) async {
  final ui.Image image = await _renderTemplateImage('A $char W', fontFamily);
  final ui.Image imageOptimized = await imageToBlackOnWhite(image);
  final Artifact imageAsMatrix = await Artifact.artifactFromImage(
    imageOptimized,
  );

  textify.extractBandsAndArtifacts(imageAsMatrix);

  if (textify.bands.list.isEmpty) {
    return;
  }

  final List<Artifact> artifacts = textify.bands.list.first.artifacts
      .where((Artifact artifact) => artifact.isNotEmpty)
      .toList();

  // Expect exactly 3 isolated artifacts: A, the target char, W.
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

  Textify.characterDefinitions.upsertTemplate(fontFamily, char, matrix);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Update Arial / Helvetica / Times New Roman templates at ${_templateFontSize}px',
    () async {
      // Load all three fonts before initialising Textify.
      for (final font in _fonts) {
        await _loadFont(font.family, font.assetPath);
      }

      final Textify textify = await Textify().init(
        pathToAssetsDefinition: 'assets/matrices.json',
      );

      // All characters covered by the OCR-eval generated-image tests.
      final List<String> allChars = [...letterUpperCase, ...letterLowerCase];

      for (final font in _fonts) {
        for (final String char in allChars) {
          await _updateTemplateForChar(textify, font.family, char);
        }
      }

      final File outFile = File('assets/matrices.json');
      await outFile.writeAsString(Textify.characterDefinitions.toJsonString());
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

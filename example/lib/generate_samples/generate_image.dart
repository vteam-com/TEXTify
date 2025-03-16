import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:textify/matrix.dart';

Future<ui.Image> generateImageDrawText({
  required final int imageWidth,
  required final int imageHeight,
  required final String text,
  required final String fontFamily,
  required final int fontSize,
  final Offset? offset,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas newCanvas = ui.Canvas(recorder);

  // Background color
  final ui.Paint paint = ui.Paint()..color = Colors.white;
  newCanvas.drawRect(
    ui.Rect.fromLTWH(0, 0, imageWidth.toDouble(), imageHeight.toDouble()),
    paint,
  );

  // Create TextPainter
  TextPainter textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.black,
        fontSize: fontSize.toDouble(),
        fontWeight: FontWeight.bold,
        fontFamily: fontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  textPainter.layout();

  textPainter.paint(newCanvas, offset ?? Offset(0, 0));

  // Convert to Image
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(imageWidth, imageHeight);
  return image;
}

Future<ui.Image> createColorImageUsingTextPainter({
  required final Color backgroundColor,
  // text 1
  required final String text1,
  required final Color textColor1,
  // text 2
  required final String text2,
  required final Color textColor2,
  // text 3
  required final String text3,
  required final Color textColor3,
  // Font
  required final String fontFamily,
  required final int fontSize,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas newCanvas = ui.Canvas(recorder);

  final ui.Paint paint = ui.Paint();
  paint.color = backgroundColor;
  paint.style = ui.PaintingStyle.fill;

  const letterSpacing = 4;

  final int maxWidthLine1 = text1.length * (fontSize + letterSpacing);
  final int maxWidthLine2 = text2.length * (fontSize + letterSpacing);
  final int maxWidthLine3 = text2.length * (fontSize + letterSpacing);

  const int padding = 20;
  final int imageWidth = padding +
      max(
        1,
        max(
          max(
            maxWidthLine1,
            maxWidthLine2,
          ),
          maxWidthLine3,
        ),
      );
  final int imageHeight = padding + (5 * fontSize);

  newCanvas.drawRect(
    ui.Rect.fromPoints(
      const ui.Offset(0.0, 0.0),
      ui.Offset(
        imageWidth.toDouble(),
        imageHeight.toDouble(),
      ),
    ),
    paint,
  );

  // Line 1
  TextPainter textPainter = myDrawText(
    paint: paint,
    width: imageWidth,
    text: text1,
    color: textColor1,
    fontSize: fontSize,
    fontFamily: fontFamily,
  );
  textPainter.paint(
    newCanvas,
    Offset(padding.toDouble(), padding.toDouble()),
  );

  // Line 2
  TextPainter textPainter2 = myDrawText(
    paint: paint,
    width: imageWidth,
    text: text2,
    color: textColor2,
    fontSize: fontSize,
    fontFamily: fontFamily,
  );
  textPainter2.paint(
    newCanvas,
    Offset(padding.toDouble(), 2 * fontSize.toDouble()),
  );

  // Line 3
  TextPainter textPainter3 = myDrawText(
    paint: paint,
    width: imageWidth,
    text: text3,
    color: textColor3,
    fontSize: fontSize,
    fontFamily: fontFamily,
  );
  textPainter3.paint(
    newCanvas,
    Offset(padding.toDouble(), 4 * fontSize.toDouble()),
  );

  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(imageWidth, imageHeight);
  return image;
}

TextPainter myDrawText({
  required final Paint paint,
  required final Color color,
  required final String text,
  required final int fontSize,
  required final String fontFamily,
  required final int width,
  int letterSpacing = 4,
}) {
  paint.color = color;

  final TextPainter textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        letterSpacing: letterSpacing.toDouble(),
        fontSize: fontSize.toDouble(),
        fontFamily: fontFamily,
      ),
    ),
    textDirection: ui.TextDirection.ltr,
  );

  textPainter.layout(
    maxWidth: width.toDouble(),
  );
  return textPainter;
}

Future<ui.Image> imageFromMatrix(final Matrix matrix) async {
  final int width = matrix.cols;
  final int height = matrix.rows;
  final Uint8List pixels = Uint8List(width * height * 4);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int pixelIndex = (y * width + x) * 4;
      final bool value = matrix.cellGet(x, y);
      final int color = value ? 0xFF000000 : 0xFFFFFFFF;

      pixels[pixelIndex] = (color >> 16) & 0xFF; // Red
      pixels[pixelIndex + 1] = (color >> 8) & 0xFF; // Green
      pixels[pixelIndex + 2] = color & 0xFF; // Blue
      pixels[pixelIndex + 3] = (color >> 24) & 0xFF; // Alpha
    }
  }

  final ui.ImmutableBuffer buffer =
      await ui.ImmutableBuffer.fromUint8List(pixels);
  final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
    buffer,
    height: height,
    width: width,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final ui.Codec codec = await descriptor.instantiateCodec();
  final ui.FrameInfo frameInfo = await codec.getNextFrame();

  return frameInfo.image;
}

import 'package:flutter/material.dart';
import 'package:textify/artifact.dart';
import 'package:textify/band.dart';
import 'package:textify/textify.dart';
import 'package:textify_dashboard/widgets/image_viewer.dart';
import 'package:textify_dashboard/widgets/paint_grid.dart';

class PaintArtifacts extends CustomPainter {
  PaintArtifacts({
    required this.textify,
    required this.viewAs,
    required this.showRegions,
    required this.showHistogram,
  });

  final Textify textify;
  final ViewAs viewAs;
  final bool showRegions;
  final bool showHistogram;

  @override
  void paint(Canvas canvas, Size size) {
    if (viewAs == ViewAs.artifacts) {
      for (final Band band in textify.bands.list) {
        if (showRegions) {
          _paintBand(
            canvas: canvas,
            title: _getBandTitle(band),
            rect: Band.getBoundingBox(band.artifacts, useAdjustedRect: false),
            backgroundColor: Colors.black,
          );
        }
        _paintArtifactsExactlyWhereTheyAreFound(
          canvas: canvas,
          artifacts: band.artifacts,
          showRegions: showRegions,
          showHistogram: showHistogram,
        );
      }
    } else {
      for (final Band band in textify.bands.list) {
        if (showRegions) {
          _paintBand(
            canvas: canvas,
            title: _getBandTitle(band),
            rect: Band.getBoundingBox(band.artifacts, useAdjustedRect: true),
            backgroundColor: Colors.black,
          );
        }
        _paintArtifactsInRow(
          canvas: canvas,
          showRegions: showRegions,
          showHistogram: showHistogram,
          artifacts: band.artifacts,
        );
      }
    }
  }

  @override
  bool shouldRepaint(PaintArtifacts oldDelegate) => false;

  /// Draws a rectangle with a background color and a border on the given canvas.
  ///
  /// Parameters:
  /// - [canvas]: The canvas on which to draw the rectangle.
  /// - [bandRect]: The [Rect] defining the position and size of the rectangle.
  /// - [backgroundColor]: The [Color] to fill the rectangle with.
  /// - [borderColor]: The [Color] of the rectangle's border.
  /// - [borderWidth]: The width of the border. Defaults to 2.0.
  void _drawRectangle(
    final Canvas canvas,
    final Rect bandRect,
    final Color backgroundColor,
    final Color borderColor, {
    final double borderWidth = 1.0,
  }) {
    // Draw the filled rectangle
    final Paint fillPaint = Paint();
    fillPaint.color = backgroundColor;
    fillPaint.isAntiAlias = false;
    canvas.drawRect(bandRect, fillPaint);

    // Draw the border
    final Paint borderPaint = Paint();
    borderPaint.color = borderColor;
    borderPaint.style = PaintingStyle.stroke;
    borderPaint.strokeWidth = borderWidth;
    borderPaint.isAntiAlias = false;
    canvas.drawRect(bandRect, borderPaint);
  }

  void _drawText(
    Canvas canvas,
    double x,
    double y,
    String text, [
    double fontSize = 10,
    TextAlign textAlign = TextAlign.left,
  ]) {
    // Draw information about the band
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x, y),
    );
  }

  String _getBandTitle(final Band band) {
    int id = textify.bands.indexOf(band) + 1;

    return '$id: found ${band.artifacts.length}   AW:${band.averageWidth.toStringAsFixed(1)}   AG:${band.averageKerning.toStringAsFixed(1)} S:${band.spacesCount}';
  }

  void _paintArtifactsInRow({
    required final Canvas canvas,
    required final List<Artifact> artifacts,
    required final bool showRegions,
    required final bool showHistogram,
  }) {
    List<Color> colors = [
      Colors.blue.shade300,
      Colors.green.shade300,
    ];

    // artifact in that band
    int id = 1;
    for (final Artifact artifact in artifacts) {
      paintMatrix(
        canvas,
        colors[id % colors.length],
        artifact.matrix.rectAdjusted.left.toInt(),
        artifact.matrix.rectAdjusted.top.toInt(),
        showHistogram ? artifact.verticalHistogram : artifact.matrix,
      );

      _drawText(
        canvas,
        artifact.matrix.rectAdjusted.topCenter.dx - 2,
        artifact.matrix.rectAdjusted.topCenter.dy - 4,
        id.toString(),
        8,
        TextAlign.center,
      );

      _drawText(
        canvas,
        artifact.matrix.rectAdjusted.bottomCenter.dx - 2,
        artifact.matrix.rectAdjusted.bottomCenter.dy - 4,
        artifact.characterMatched,
        8,
        TextAlign.center,
      );
      id++;
    }
  }

  void _paintArtifactsExactlyWhereTheyAreFound({
    required final Canvas canvas,
    required final List<Artifact> artifacts,
    required final bool showRegions,
    required final bool showHistogram,
  }) {
    // Rainbow colors
    List<Color> colors = [
      Colors.red.shade200,
      Colors.orange.shade200,
      Colors.yellow.shade200,
      Colors.green.shade200,
      Colors.blue.shade200,
      Colors.indigo.shade200,
      Colors.deepPurple.shade200, // Using deepPurple as it's closer to violet
    ];

    // artifact in that band
    int index = 0;
    for (Artifact artifact in artifacts) {
      paintMatrix(
        canvas,
        colors[index++ % colors.length],
        artifact.matrix.rectOriginal.left.toInt(),
        artifact.matrix.rectOriginal.top.toInt(),
        showHistogram ? artifact.verticalHistogram : artifact.matrix,
      );
    }
  }

  void _paintBand({
    required final Canvas canvas,
    required String title,
    required Rect rect,
    required final Color backgroundColor,
  }) {
    // main region in blue
    _drawRectangle(
      canvas,
      rect,
      backgroundColor,
      Colors.white.withAlpha(100),
    );

    // information about the band
    if (title.isNotEmpty) {
      _drawText(
        canvas,
        rect.left,
        rect.top - 14,
        title,
      );
    }
  }
}

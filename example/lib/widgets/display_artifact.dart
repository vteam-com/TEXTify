import 'package:flutter/material.dart';
import 'package:textify/artifact.dart';
import 'package:textify/band.dart';
import 'package:textify/textify.dart';
import 'package:textify_dashboard/widgets/paint_grid.dart';

enum ViewAs {
  original,
  originalHistogram,
  matrix,
  matrixHistogram,
}

class DisplayArtifacts extends CustomPainter {
  DisplayArtifacts({
    required this.textify,
    required this.viewAs,
  });

  final Textify textify;
  final ViewAs viewAs;

  @override
  void paint(Canvas canvas, Size size) {
    if (viewAs == ViewAs.original || viewAs == ViewAs.originalHistogram) {
      _paintArtifactsExactlyWhereTheyAreFound(
        canvas: canvas,
        viewAs: viewAs,
        artifacts: textify.artifactsFound,
      );
    } else {
      for (final Band band in textify.bands) {
        _paintBand(canvas: canvas, band: band, backgroundColor: Colors.black);
        _paintArtifactsInRow(
          canvas: canvas,
          viewAs: viewAs,
          artifacts: band.artifacts,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DisplayArtifacts oldDelegate) => false;

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
    required final ViewAs viewAs,
    required final List<Artifact> artifacts,
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
        artifact.matrix.originRectangle.left.toInt(),
        artifact.matrix.originRectangle.top.toInt(),
        viewAs == ViewAs.matrixHistogram
            ? artifact.verticalHistogram
            : artifact.matrix,
      );

      _drawText(
        canvas,
        artifact.matrix.originRectangle.left,
        artifact.matrix.originRectangle.top,
        id.toString(),
        8,
      );
      id++;
    }
  }

  void _paintArtifactsExactlyWhereTheyAreFound({
    required final Canvas canvas,
    required final ViewAs viewAs,
    required final List<Artifact> artifacts,
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
        artifact.matrix.originRectangle.left.toInt(),
        artifact.matrix.originRectangle.top.toInt(),
        viewAs == ViewAs.original
            ? artifact.matrix
            : artifact.verticalHistogram,
      );
    }
  }

  void _paintBand({
    required final Canvas canvas,
    required final Band band,
    required final Color backgroundColor,
  }) {
    final String caption = _getBandTitle(band);
    final Rect bandRect = Band.getBoundingBox(band.artifacts);

    // main region in blue
    _drawRectangle(
      canvas,
      bandRect,
      backgroundColor,
      Colors.white.withAlpha(100),
    );

    // information about the band
    if (caption.isNotEmpty) {
      _drawText(
        canvas,
        bandRect.left,
        bandRect.top - 12,
        caption,
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:textify/band.dart';
import 'package:textify/models/int_rect.dart';
import 'package:textify/textify.dart';
import 'package:textify_dashboard/generate_samples/generate_image.dart';
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
    for (final Band band in textify.bands.list) {
      if (showRegions) {
        _paintBand(
          canvas: canvas,
          title: _getBandTitle(band),
          rect: Band.getBoundingBox(
            band.artifacts,
            useAdjustedRect: viewAs == ViewAs.characters,
          ),
          backgroundColor: Colors.black,
        );
      }
      if (viewAs == ViewAs.artifacts) {
        _paintArtifactsExactlyWhereTheyAreFound(
          canvas: canvas,
          artifacts: band.artifacts,
          showRegions: showRegions,
          showHistogram: showHistogram,
        );
      } else {
        _paintArtifactsInRow(
          canvas: canvas,
          artifacts: band.artifacts,
          showRegions: showRegions,
          showHistogram: showHistogram,
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
    final IntRect bandRect,
    final Color backgroundColor,
    final Color borderColor, {
    final double borderWidth = 1.0,
  }) {
    // Draw the filled rectangle
    final Paint fillPaint = Paint();
    fillPaint.color = backgroundColor;
    fillPaint.isAntiAlias = false;
    canvas.drawRect(intRectToRectDouble(bandRect), fillPaint);

    // Draw the border
    final Paint borderPaint = Paint();
    borderPaint.color = borderColor;
    borderPaint.style = PaintingStyle.stroke;
    borderPaint.strokeWidth = borderWidth;
    borderPaint.isAntiAlias = false;
    canvas.drawRect(intRectToRectDouble(bandRect), borderPaint);
  }

  void _drawText(
    Canvas canvas,
    int x,
    int y,
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
      Offset(x.toDouble(), y.toDouble()),
    );
  }

  String _getBandTitle(final Band band) {
    int id = textify.bands.list.indexOf(band) + 1;
    return '#$id$band';
  }

  /// Creates a new Artifact representing the horizontal histogram of this artifact.
  ///
  /// The horizontal histogram visualizes the count of true cells in each column
  /// as a vertical bar. The resulting artifact has the same dimensions as the original,
  /// with each column filled from the bottom up based on the count of true cells.
  ///
  /// Returns a new Artifact representing the horizontal histogram.
  Artifact getHistogramHorizontalArtifact(final Artifact artifact) {
    int width = artifact.cols;

    // Step 1: Compute vertical projection (count active pixels per column)
    List<int> histogram = artifact.getHistogramHorizontal();

    // Step 2: Create an empty matrix for the projection
    Artifact result = Artifact(artifact.cols, artifact.rows);

    // Step 3: Fill the matrix from the bottom up based on the projection counts
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < histogram[x]; y++) {
        result.cellSet(x, artifact.rows - 1 - y, true);
      }
    }

    return result;
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
        artifact.wasPartOfSplit
            ? Colors.limeAccent
            : colors[id % colors.length],
        artifact.rectAdjusted.left.toInt(),
        artifact.rectAdjusted.top.toInt(),
        showHistogram ? getHistogramHorizontalArtifact(artifact) : artifact,
        background: artifact.matchingCharacter == ' ' ? Colors.grey : null,
      );

      _drawText(
        canvas,
        artifact.rectAdjusted.topCenter.x - (id.toString().length * 2),
        artifact.rectAdjusted.topCenter.y - 8,
        id.toString(),
        8,
        TextAlign.left,
      );

      _drawText(
        canvas,
        artifact.rectAdjusted.bottomCenter.x - 2,
        artifact.rectAdjusted.bottomCenter.y - 2,
        artifact.matchingCharacter,
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
      Color color = colors[index++ % colors.length];
      if (artifact.needsInspection) {
        color = Colors.red;
      }
      if (artifact.wasPartOfSplit) {
        color = Colors.white;
      }

      paintMatrix(
        canvas,
        color,
        artifact.rectFound.left.toInt(),
        artifact.rectFound.top.toInt(),
        showHistogram ? getHistogramHorizontalArtifact(artifact) : artifact,
      );
    }
  }

  void _paintBand({
    required final Canvas canvas,
    required String title,
    required IntRect rect,
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
        rect.top - 20,
        title,
      );
    }
  }
}

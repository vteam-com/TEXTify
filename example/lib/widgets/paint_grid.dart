import 'package:flutter/material.dart';
import 'package:textify/artifact.dart';

class DisplayMatrix extends StatelessWidget {
  const DisplayMatrix({
    super.key,
    required this.matrix1,
    this.matrix2,
    this.pixelSize = 1,
  });

  final Artifact matrix1;
  final Artifact? matrix2;
  final double pixelSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: matrix1.cols * pixelSize,
      height: matrix1.rows * pixelSize,
      child: CustomPaint(
        painter: DisplayMatrixPaint(
          matrix1: matrix1,
          matrix2: matrix2,
          pixelSize: pixelSize,
        ),
      ),
    );
  }
}

class DisplayMatrixPaint extends CustomPainter {
  DisplayMatrixPaint({
    required this.matrix1,
    this.matrix2,
    this.pixelSize = 1,
  });

  final Artifact matrix1;
  final Artifact? matrix2;
  final double pixelSize;

  @override
  void paint(Canvas canvas, Size size) {
    // Paints the bands and artifacts on the canvas in their original positions.
    if (this.matrix2 == null) {
      paintMatrix(canvas, Colors.blue, 0, 0, matrix1, pixelSize: pixelSize);
    } else {
      paintOverlay(canvas, 0, 0, matrix1, matrix2!, pixelSize);
    }
  }

  @override
  bool shouldRepaint(DisplayMatrixPaint oldDelegate) => false;
}

void paintMatrix(
  final Canvas canvas,
  final Color pixelColor,
  final int startX,
  final int startY,
  final Artifact matrix, {
  final double pixelSize = 1,
  Color? background,
}) {
  final double gapForOn = pixelSize * (10 / 100); // 10%
  final double gapForOff = gapForOn * 2; // 20%
  final double sizeForOn = pixelSize - (gapForOn * 2);
  final double sizeForOff = pixelSize - (gapForOff * 2);
  background ??= Colors.white.withAlpha(
    50,
  );

  final paintBackground = Paint();
  paintBackground.style = PaintingStyle.fill;
  paintBackground.color = background;

  final paintForeground = Paint();
  paintForeground.style = PaintingStyle.fill;
  paintForeground.color = pixelColor;

  final int rows = matrix.rows;
  final int cols = matrix.cols;

  for (int x = 0; x < cols; x++) {
    final double xPos = startX + x.toDouble();
    for (int y = 0; y < rows; y++) {
      final double yPos = startY + y.toDouble();
      if (matrix.cellGet(x, y)) {
        canvas.drawRect(
          Rect.fromLTWH(
            xPos * pixelSize + gapForOn,
            yPos * pixelSize + gapForOn,
            sizeForOn,
            sizeForOn,
          ),
          paintForeground,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTWH(
            xPos * pixelSize + gapForOff,
            yPos * pixelSize + gapForOff,
            sizeForOff,
            sizeForOff,
          ),
          paintBackground,
        );
      }
    }
  }
}

void paintOverlay(
  final Canvas canvas,
  final int startX,
  final int startY,
  final Artifact matrix1,
  final Artifact matrix2, [
  final double pixelSize = 1,
]) {
  paintMatrix(
    canvas,
    Colors.blue,
    startX,
    startY,
    matrix1,
    pixelSize: pixelSize,
  );
  paintMatrix(
    canvas,
    Colors.yellow.withAlpha(130),
    startX,
    startY,
    matrix2,
    pixelSize: pixelSize,
    background: Colors.transparent,
  );
}

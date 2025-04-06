import 'package:flutter/material.dart';
import 'package:textify/artifact.dart';
import 'package:textify_dashboard/widgets/paint_grid.dart';

/// A widget that displays an artifact with its details.
class DisplayArtifact extends StatelessWidget {
  const DisplayArtifact({
    super.key,
    required this.artifact,
    this.showHistogram = false,
    this.pixelSize = 4.0,
  });

  final Artifact artifact;
  final bool showHistogram;
  final double pixelSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Artifact visualization
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withAlpha(100)),
            borderRadius: BorderRadius.circular(4),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            width: artifact.cols * pixelSize,
            height: artifact.rows * pixelSize,
            child: CustomPaint(
              painter: _ArtifactPainter(
                artifact: artifact,
                showHistogram: showHistogram,
                pixelSize: pixelSize,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtifactPainter extends CustomPainter {
  const _ArtifactPainter({
    required this.artifact,
    required this.showHistogram,
    required this.pixelSize,
  });

  final Artifact artifact;
  final bool showHistogram;
  final double pixelSize;

  @override
  void paint(Canvas canvas, Size size) {
    final Color color = artifact.needsInspection
        ? Colors.red
        : artifact.wasPartOfSplit
            ? Colors.lightGreenAccent
            : Colors.blue.shade300;

    paintMatrix(
      canvas,
      color,
      0,
      0,
      showHistogram ? _getHistogramHorizontalArtifact(artifact) : artifact,
      pixelSize: pixelSize,
    );
  }

  @override
  bool shouldRepaint(_ArtifactPainter oldDelegate) =>
      oldDelegate.artifact != artifact ||
      oldDelegate.showHistogram != showHistogram ||
      oldDelegate.pixelSize != pixelSize;

  /// Creates a new Artifact representing the horizontal histogram of this artifact.
  Artifact _getHistogramHorizontalArtifact(final Artifact artifact) {
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
}

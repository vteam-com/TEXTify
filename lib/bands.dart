import 'dart:math';
import 'package:textify/artifact.dart';
import 'package:textify/band.dart';
import 'package:textify/int_rect.dart';

/// Exports
export 'package:textify/band.dart';

///
class Bands {
  ///
  Bands([List<Band> bands = const <Band>[]]) {
    list.addAll(bands);
  }

  /// List of text bands identified in the image.
  final List<Band> list = [];

  ///
  void clear() => list.clear();

  ///
  int get length => list.length;

  ///
  int get totalArtifacts =>
      this.list.fold(0, (sum, band) => sum + band.artifacts.length);

  ///
  void add(final Band band) {
    list.add(band);
  }

  ///
  void addAll(final List<Band> bands) {
    list.addAll(bands);
  }

  ///
  int indexOf(final Band band) {
    return list.indexOf(band);
  }

  /// Groups artifacts into horizontal bands based on their vertical positions.
  ///
  /// This method organizes artifacts into bands, which are horizontal groupings
  /// of artifacts that are vertically close to each other. The process involves:
  /// 1. Sorting artifacts by their top y-position.
  /// 2. Iterating through sorted artifacts and assigning them to existing bands
  ///    or creating new bands as necessary.
  ///
  /// The method uses a vertical tolerance to determine if an artifact belongs
  /// to an existing band.
  void mergeBandsHorizontally() {
    bool mergedAny = true;
    while (mergedAny) {
      mergedAny = false;

      for (int i = 0; i < list.length - 1; i++) {
        Band leftBand = list[i];
        Band rightBand = list[i + 1];

        //
        // Step 1 - Calculate vertical center overlap
        //
        int leftCenter = leftBand.rectangleAdjusted.center.y;
        int rightCenter = rightBand.rectangleAdjusted.center.y;
        int centerDiff = (leftCenter - rightCenter).abs();
        int avgHeight = (leftBand.rectangleAdjusted.height +
                rightBand.rectangleAdjusted.height) ~/
            2;

        // Check if bands are horizontally adjacent and vertically aligned
        if (centerDiff < avgHeight * 1.5) {
          //
          // Step 2 - Calculate horizontal distance between bands
          //
          int horizontalDistance = rightBand.rectangleAdjusted.left -
              leftBand.rectangleAdjusted.right;

          // Centers are within 30% of average height
          if (horizontalDistance > 0) {
            final maxAvgWidth =
                max(leftBand.averageWidth, rightBand.averageWidth);
            // Bands don't overlap
            if (horizontalDistance <= (maxAvgWidth * 3)) {
              // Merge right band artifacts into left band
              for (var artifact in rightBand.artifacts) {
                leftBand.addArtifact(artifact);
              }

              // Remove the right band
              list.removeAt(i + 1);
              mergedAny = true;
              break;
            }
          }
        }
      }
    }
  }

  /// Removes bands that have no artifacts from the given list
  void removeEmptyBands() {
    list.removeWhere((band) {
      band.removeEmptyArtifacts();
      return band.artifacts.isEmpty;
    });
  }

  ///
  void trimBands() {
    this.list.forEach((band) {
      band.trim();
    });
  }

  ///
  void sortTopLeftToBottomRight() {
    list.sort(
      (a, b) => (a.rectangleOriginal.center.y
                  .compareTo(b.rectangleOriginal.center.y) !=
              0)
          ? a.rectangleOriginal.center.y.compareTo(b.rectangleOriginal.center.y)
          : a.rectangleOriginal.center.x
              .compareTo(b.rectangleOriginal.center.x),
    );
  }

  ///
  static Bands getBandsOfArtifacts(
    Artifact matrixSourceImage,
    List<IntRect> regions,
    bool innerSplit,
  ) {
    Bands bandsFound = Bands();

    // Explore each regions/rectangles
    for (final IntRect regionFromDilated in regions) {
      //
      final Artifact regionMatrixFromImage = Artifact.extractSubGrid(
        matrix: matrixSourceImage,
        rect: regionFromDilated,
      );

      bandsFound.add(
        rowToBand(
          regionMatrix: regionMatrixFromImage,
          offset: regionFromDilated.topLeft,
        ),
      );
    }

    //
    // Clean up bands
    //
    bandsFound.removeEmptyBands();

    // additional clean up of the artifacts in each band
    for (final Band band in bandsFound.list) {
      // Start by matching adjusted location to the location found
      band.artifacts.forEach((a) {
        a.locationAdjusted = IntOffset(a.locationFound.x, a.locationFound.y);
      });

      band.sortArtifactsLeftToRight();
    }

    bandsFound.mergeBandsHorizontally();

    // Pack each Bands
    sortVerticallyThenHorizontally(bandsFound.list);

    for (final Band band in bandsFound.list) {
      band.padVerticallyArtifactToMatchTheBand();
      if (innerSplit) {
        band.identifySuspiciousLargeArtifacts();
      }
      band.identifySpacesInBand();
      band.packArtifactLeftToRight();
    }
    return bandsFound;
  }

  ///
  static void sortVerticallyThenHorizontally(
    List<Band> list, {
    double threshold = 5.0,
  }) {
    list.sort((a, b) {
      // If the vertical difference is within the threshold, treat them as the same row
      if ((a.rectangleOriginal.center.y - b.rectangleOriginal.center.y).abs() <=
          threshold) {
        return a.rectangleOriginal.center.x.compareTo(
          b.rectangleOriginal.center.x,
        ); // Sort by X-axis if on the same line
      }
      return a.rectangleOriginal.center.y.compareTo(
        b.rectangleOriginal.center.y,
      ); // Otherwise, sort by Y-axis
    });
  }

  ///
  String getText() {
    String text = '';
    list.forEach(
      (final Band band) {
        text += band.getText();
      },
    );
    return text;
  }
}

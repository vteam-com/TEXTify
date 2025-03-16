import 'dart:ui';

import 'package:textify/artifact.dart';
import 'package:textify/band.dart';
import 'package:textify/matrix.dart';

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
        double leftCenter = leftBand.rectangleAdjusted.center.dy;
        double rightCenter = rightBand.rectangleAdjusted.center.dy;
        double centerDiff = (leftCenter - rightCenter).abs();
        double avgHeight = (leftBand.rectangleAdjusted.height +
                rightBand.rectangleAdjusted.height) /
            2;

        // Check if bands are horizontally adjacent and vertically aligned
        if (centerDiff < avgHeight * 0.3) {
          //
          // Step 2 - Calculate horizontal distance between bands
          //
          double horizontalDistance = rightBand.rectangleAdjusted.left -
              leftBand.rectangleAdjusted.right;

          // Centers are within 30% of average height
          if (horizontalDistance > 0) {
            // Bands don't overlap
            if (horizontalDistance <= (leftBand.averageWidth * 1.9)) {
              final Artifact artifactSpace =
                  Artifact.fromMatrix(Matrix(10, avgHeight, false));
              final Matrix lastArtifactOfLeftBandMatix =
                  leftBand.artifacts.last.matrix;
              final locationForSpaceX =
                  lastArtifactOfLeftBandMatix.locationFound.dx +
                      lastArtifactOfLeftBandMatix.cols;

              artifactSpace.matrix.locationFound = Offset(
                locationForSpaceX + 2,
                lastArtifactOfLeftBandMatix.locationFound.dy,
              );
              leftBand.addArtifact(artifactSpace);

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
      (a, b) => (a.rectangleOriginal.center.dy
                  .compareTo(b.rectangleOriginal.center.dy) !=
              0)
          ? a.rectangleOriginal.center.dy
              .compareTo(b.rectangleOriginal.center.dy)
          : a.rectangleOriginal.center.dx
              .compareTo(b.rectangleOriginal.center.dx),
    );
  }

  ///
  static Bands getBandsOfArtifacts(
    Matrix matrixSourceImage,
    List<Rect> regions,
  ) {
    Bands bandsFound = Bands();

    // Explore each regions/rectangles
    for (final Rect regionFromDilated in regions) {
      //
      final Matrix regionMatrixFromImage = Matrix.extractSubGrid(
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
        a.matrix.locationAdjusted =
            Offset(a.matrix.locationFound.dx, a.matrix.locationFound.dy);
      });

      band.sortArtifactsLeftToRight();
    }

    bandsFound.mergeBandsHorizontally();

    // Pack each Bands
    sortVeticalyThenHorizontally(bandsFound.list);

    for (final Band band in bandsFound.list) {
      band.paddVerticallyArtrifactToMatchTheBand();
      band.packArtifactLeftToRight();
      band.identifySpacesInBand();
    }
    return bandsFound;
  }

  ///
  static void sortVeticalyThenHorizontally(
    List<Band> list, {
    double threshold = 5.0,
  }) {
    list.sort((a, b) {
      // If the vertical difference is within the threshold, treat them as the same row
      if ((a.rectangleOriginal.center.dy - b.rectangleOriginal.center.dy)
              .abs() <=
          threshold) {
        return a.rectangleOriginal.center.dx.compareTo(
          b.rectangleOriginal.center.dx,
        ); // Sort by X-axis if on the same line
      }
      return a.rectangleOriginal.center.dy.compareTo(
        b.rectangleOriginal.center.dy,
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

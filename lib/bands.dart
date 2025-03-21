import 'dart:math';
import 'package:textify/band.dart';
import 'package:textify/int_rect.dart';

/// Exports
export 'package:textify/band.dart';

/// Manages a collection of text bands identified in an image, providing methods for processing, merging, sorting, and extracting text from these bands.
///
/// This class handles the organization of text artifacts into horizontal bands,
/// with capabilities to merge, remove empty bands, sort, and extract text content.
/// It supports operations like identifying artifacts, adjusting their locations,
/// and preparing text bands for further analysis.
class Bands {
  /// Creates a new Bands instance with an optional initial list of bands.
  Bands([List<Band> bands = const <Band>[]]) {
    list.addAll(bands);
  }

  /// List of text bands identified in the image.
  final List<Band> list = [];

  /// Clears all bands from the collection.
  void clear() => list.clear();

  /// Returns the number of bands in the collection.
  int get length => list.length;

  /// Returns the total number of artifacts across all bands, including newline characters.
  ///
  /// Each band contributes its artifacts count plus one for the newline character,
  /// except for the last band where the newline is not counted.
  int get totalArtifacts {
    int countCharacters = 0;

    for (final band in this.list) {
      countCharacters += band.artifacts.length;
      countCharacters += 1; // For NewLine '\n'
    }
    // last \n needs to be discounted since, the returned string will not include the last '\n'
    countCharacters--;
    return countCharacters;
  }

  /// Adds a new band to the collection.
  void add(final Band band) {
    list.add(band);
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

  /// Removes bands that have no artifacts from the collection.
  ///
  /// First removes empty artifacts from each band, then removes bands
  /// that have no remaining artifacts.
  void removeEmptyBands() {
    list.removeWhere((band) {
      band.removeEmptyArtifacts();
      return band.artifacts.isEmpty;
    });
  }

  /// Sorts bands from top to bottom and left to right based on their original positions.
  ///
  /// Uses the center points of the original rectangles for comparison.
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

  /// Processes and transforms a collection of artifacts from source image regions into organized bands.
  ///
  /// Takes a source image matrix, a list of rectangular regions, and an inner split flag to:
  /// - Extract artifacts from each region
  /// - Remove empty bands
  /// - Adjust artifact locations
  /// - Sort and merge artifacts and bands
  /// - Optionally identify suspicious artifacts
  /// - Pack artifacts within bands
  ///
  /// Returns a processed [Bands] collection ready for further analysis.
  ///
  /// [matrixSourceImage] The source image matrix to extract artifacts from.
  /// [regions] List of rectangular regions to process.
  /// [innerSplit] Flag to enable additional artifact splitting analysis.
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

  /// Sorts a list of bands vertically then horizontally with a threshold for vertical alignment.
  ///
  /// [list] The list of bands to sort.
  /// [threshold] The vertical threshold (in pixels) within which bands are considered to be on the same line.
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

  /// Returns the concatenated text content of all bands in the collection.
  ///
  /// Each band's text is separated by a newline character.
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

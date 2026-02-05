/// This library is part of the Textify package.
/// Provides functionality for managing collections of text bands identified in images.
library;

import 'package:textify/band.dart';
import 'package:textify/image_helpers.dart';

/// Exports
export 'package:textify/band.dart';

/// Manages a collection of text bands identified in an image, providing methods for processing, merging, sorting, and extracting text from these bands.
///
/// This class handles the organization of text artifacts into horizontal bands,
/// with capabilities to merge, remove empty bands, sort, and extract text content.
/// It supports operations like identifying artifacts, adjusting their locations,
/// and preparing text bands for further analysis.
class Bands {
  static const int _averageDivisor = 2;
  static const double _verticalAlignmentRatio = 0.4;
  static const double _estimatedSpaceWidthMultiplier = 1.2;
  static const double _defaultSortThreshold = 5.0;

  /// Initializes a new empty Bands collection.
  ///
  /// Creates a collection with an empty list of bands ready to be populated.
  Bands([List<Band> bands = const <Band>[]]) {
    list.addAll(bands);
  }

  /// List of text bands identified in the image.
  final List<Band> list = [];

  /// Clears all bands from the collection.
  void clear() => list.clear();

  /// Gets the number of bands in the collection.
  ///
  /// Returns the count of bands currently in this collection.
  int get length => list.length;

  /// Gets the number of characters across all bands in the collection.
  ///
  /// Counts the total number of matched characters in all artifacts
  /// within all bands.
  ///
  /// Returns the total character count.
  int get totalArtifacts {
    int countCharacters = 0;

    for (final band in list) {
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

  /// Determines if two bands are approximately on the same horizontal row.
  ///
  /// This method checks if two bands should be considered part of the same horizontal line
  /// by evaluating two criteria:
  /// 1. The bands must have some vertical overlap
  /// 2. The vertical distance between their centers must be less than 40% of their average height
  ///
  /// [a] The first band to compare
  /// [b] The second band to compare
  ///
  /// Returns `true` if the bands are considered to be on the same horizontal row, `false` otherwise.
  bool areBandAlmostOnTheSameHorizontalRow(Band a, Band b) {
    // They have to at least overlap
    if (a.rectangleAdjusted.intersectVertically(b.rectangleAdjusted)) {
      //
      // the two bands are relative on the same horizontal row
      //
      //
      // Step 2 - How much vertically, should we consider it aligned?
      //
      int verticalDistance =
          (a.rectangleAdjusted.center.y - b.rectangleAdjusted.center.y).abs();

      int avgHeightOfBothBands =
          (a.rectangleAdjusted.height + b.rectangleAdjusted.height) ~/
          _averageDivisor;

      // The bands needs an vertical overlapping of least 50% of the average height
      if (verticalDistance < avgHeightOfBothBands * _verticalAlignmentRatio) {
        return true;
      }
    }
    return false;
  }

  /// Return groups of band that are relatively on the same aligned row
  List<List<Band>> getBandsOnTheSameRelativeRow() {
    List<List<Band>> rows = [];
    if (list.isEmpty) {
      return rows;
    }

    List<Band> currentRow = [list[0]];

    for (int i = 1; i < list.length; i++) {
      Band currentBand = list[i];
      Band lastBandInRow = currentRow.last;

      if (areBandAlmostOnTheSameHorizontalRow(lastBandInRow, currentBand)) {
        currentRow.add(currentBand);
      } else {
        rows.add(List.from(currentRow));
        currentRow = [currentBand];
      }
    }

    rows.add(currentRow);
    return rows;
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
    final List<List<Band>> rowOfBands = getBandsOnTheSameRelativeRow();

    for (final bands in rowOfBands) {
      // ensure that we are looking from left to right
      bands.sort(
        (a, b) => a.rectangleAdjusted.left.compareTo(b.rectangleAdjusted.left),
      );

      while (tryMergeBands(bands)) {
        continue;
      }
    }
  }

  /// Attempts to merge adjacent bands that are close enough horizontally.
  ///
  /// Iterates through the list of bands and tries to merge each band with its
  /// immediate neighbor if they meet the horizontal proximity criteria.
  ///
  /// Returns `true` if a merge was successful, `false` otherwise.
  bool tryMergeBands(List<Band> bandOnPossibleRow) {
    for (int i = 0; i < bandOnPossibleRow.length - 1; i++) {
      Band bandWest = bandOnPossibleRow[i];
      Band bandEast = bandOnPossibleRow[i + 1];

      if (shouldMergeBands(bandWest, bandEast)) {
        bandWest.addArtifacts(bandEast.artifacts);
        list.remove(bandEast);
        bandOnPossibleRow.remove(bandEast);
        return true;
      }
    }
    return false;
  }

  /// Determines whether two bands should be merged based on their horizontal proximity.
  ///
  /// Calculates the horizontal distance between bands and compares it against
  /// an estimated space width derived from the average band height. Bands are
  /// considered mergeable if they are close enough horizontally.
  ///
  /// [bandWest] The band positioned to the left or west.
  /// [bandEast] The band positioned to the right or east.
  ///
  /// Returns `true` if the bands should be merged, `false` otherwise.
  bool shouldMergeBands(Band bandWest, Band bandEast) {
    final int horizontalDistance =
        bandEast.rectangleAdjusted.left - bandWest.rectangleAdjusted.right;

    final int avgHeightOfBothBands =
        (bandEast.rectangleAdjusted.height +
            bandWest.rectangleAdjusted.height) ~/
        _averageDivisor;

    final estimatedSpaceWidth =
        avgHeightOfBothBands * _estimatedSpaceWidthMultiplier;

    return horizontalDistance > 0 && horizontalDistance <= estimatedSpaceWidth;
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
      (a, b) =>
          (a.rectangleOriginal.center.y.compareTo(
                b.rectangleOriginal.center.y,
              ) !=
              0)
          ? a.rectangleOriginal.center.y.compareTo(b.rectangleOriginal.center.y)
          : a.rectangleOriginal.center.x.compareTo(
              b.rectangleOriginal.center.x,
            ),
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
      final Artifact regionMatrixFromImage = matrixSourceImage.extractSubGrid(
        rect: regionFromDilated,
      );

      bandsFound.add(
        Band.splitArtifactIntoBand(
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
      for (final a in band.artifacts) {
        a.locationAdjusted = IntOffset(a.locationFound.x, a.locationFound.y);
      }

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
    double threshold = _defaultSortThreshold,
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
    for (final Band band in list) {
      text += band.getText();
    }
    return text;
  }
}

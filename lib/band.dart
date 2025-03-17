import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:textify/artifact.dart';
import 'package:textify/int_rect.dart';

/// Represents a horizontal band (aka strip) in an image/document.
///
/// A Band contains multiple [Artifact] objects and provides methods for
/// analyzing their layout and characteristics.
class Band {
  /// Creates a new Band with the specified rectangle.
  ///
  Band();

  /// List of artifacts contained within this band.
  List<Artifact> artifacts = [];

  ///
  String getText() {
    String text = '';

    artifacts.forEach((a) => text += a.characterMatched);
    return text;
  }

  /// Private fields to store calculated average of space between each artifacts
  int _averageKerning = -1;

  /// Private fields to store calculated average of artifact width
  int _averageWidth = -1;

  /// Gets the average kerning between adjacent artifacts in the band.
  ///
  /// Triggers calculation if not previously computed.
  ///
  /// Returns:
  /// The average kerning as a double, or -1 if there are fewer than 2 artifacts.
  int get averageKerning {
    if ((_averageKerning == -1 || _averageWidth == -1)) {
      _updateStatistics();
    }
    return _averageKerning;
  }

  /// Kerning between each artifact when applying packing
  static int kerningWidth = 4;

  /// Gets the average width of artifacts in the band.
  ///
  /// Triggers calculation if not previously computed.
  ///
  /// Returns:
  /// The average width as a double, or -1 if there are fewer than 2 artifacts.
  int get averageWidth {
    if ((_averageKerning == -1 || _averageWidth == -1)) {
      _updateStatistics();
    }
    return _averageWidth;
  }

  ///
  void removeEmptyArtifacts() {
    artifacts.removeWhere((artifact) => artifact.isEmpty);
  }

  /// Calculates the average Kerning between adjacent artifacts and their average width.
  ///
  /// This method computes the mean horizontal distance between the right edge of
  /// one artifact and the left edge of the next artifact in the list. It also
  /// calculates the average width of all artifacts. The artifacts are assumed
  /// to be sorted from left to right.
  ///
  /// If there are fewer than 2 artifacts, both averages are set to -1.
  void _updateStatistics() {
    if (artifacts.length < 2) {
      _averageKerning = -1;
      _averageWidth = rectangleAdjusted.width;
      return;
    }

    double totalWidth = 0;
    double totalKerning = 0;
    int count = artifacts.length;

    for (int i = 1; i < artifacts.length; i++) {
      final artifact = artifacts[i];
      totalWidth += artifact.rectAdjusted.width;

      final int kerning =
          artifact.rectAdjusted.left - artifacts[i - 1].rectAdjusted.right;
      totalKerning += kerning;
    }
    _averageWidth = (totalWidth / count).round();
    _averageKerning = (totalKerning / count).round();
  }

  /// Adds the given artifact to the band.
  ///
  /// This method adds the provided [artifact] to the list of artifacts in the band.
  /// It also resets the cached rectangle, as the addition or removal of an artifact
  /// can affect the overall layout and dimensions of the band.
  void addArtifact(final Artifact artifact) {
    // reset the cached rectangle each time an artifact is added or removed
    this.artifacts.add(artifact);
  }

  /// Sorts the artifacts in this band from left to right.
  ///
  /// This method orders the artifacts based on their left edge position,
  /// ensuring they are in the correct sequence as they appear in the band.
  void sortArtifactsLeftToRight() {
    artifacts.sort(
      (a, b) => a.rectAdjusted.left.compareTo(b.rectAdjusted.left),
    );
  }

  /// Using the average artifact width, fine the ones that have an outlier width
  /// and tag them needsInspection=true
  void identifySuspiciousLargeArtifacts() {
    final List<Artifact> listToInspect = [];

    final double thresholdWidth = this.averageWidth * 2;

    for (final Artifact artifact in this.artifacts) {
      artifact.needsInspection = artifact.cols > thresholdWidth;
      if (artifact.needsInspection) {
        listToInspect.add(artifact);
      }
    }

    for (final artifactToSplit in listToInspect) {
      final List<int> peaksAndValleys =
          artifactToSplit.getHistogramHorizontal();

      final int valleySeperatorValueToSplitOn =
          calculateThreshold(peaksAndValleys);

      // Find the valley where two charactes are touching
      List<int> columnSeparators =
          keepIndexBelowValue(peaksAndValleys, valleySeperatorValueToSplitOn);

      columnSeparators = normalizeHistogram(columnSeparators);
      if (columnSeparators.isNotEmpty) {
        // Ensure the first and last rows are included as split points.
        if (columnSeparators.first != 0) {
          columnSeparators.insert(0, 0);
        }
        if (columnSeparators.last != artifactToSplit.cols) {
          columnSeparators.add(artifactToSplit.cols);
        }

        final List<Artifact> artifactsFromColumns =
            Artifact.splitAsColumns(artifactToSplit, columnSeparators);

        this.replaceOneArtifactWithMore(artifactToSplit, artifactsFromColumns);
      }
    }
  }

  ///
  List<int> normalizeHistogram(List<int> histogram) {
    List<int> normalized = [];
    List<int> sequence = [];

    for (int i = 0; i < histogram.length; i++) {
      if (sequence.isEmpty) {
        sequence.add(histogram[i]);
      } else {
        // Check if the current value is consecutive to the last value
        if (histogram[i] == sequence.last + 1) {
          sequence.add(histogram[i]);
        } else {
          // If the sequence ends, find the middle point and add it
          int middle = sequence[(sequence.length - 1) ~/ 2];
          normalized.add(middle);

          // Reset sequence for the next consecutive sequence
          sequence = [histogram[i]];
        }
      }
    }

    // Don't forget to add the last sequence
    if (sequence.isNotEmpty) {
      int middle = sequence[(sequence.length - 1) ~/ 2];
      normalized.add(middle);
    }

    return normalized;
  }

  ///
  static void sortArtifactByRectFound(List<Artifact> list) {
    list.sort((Artifact a, Artifact b) {
      final aCenterY = a.rectFound.top + a.rectFound.height / 2;
      final bCenterY = b.rectFound.top + b.rectFound.height / 2;
      if ((aCenterY - bCenterY).abs() < 10) {
        return a.rectFound.left.compareTo(b.rectFound.left);
      }
      return aCenterY.compareTo(bCenterY);
    });
  }

  ///
  void replaceOneArtifactWithMore(
    final Artifact artifactToReplace,
    final List<Artifact> artifactsToInsert,
  ) {
    int index = this.artifacts.indexOf(artifactToReplace);
    this.artifacts.removeAt(index);
    this.artifacts.insertAll(index, artifactsToInsert);
  }

  /// Splits artifact in two
  List<Artifact> splitArtifact(
    final Artifact artifactToSplit,
    final List<int> splitOnTheseColumns,
  ) {
    List<Artifact> splits = [];

    int startingCol = 0;

    for (int c in splitOnTheseColumns) {
      // Create the first sub-grid from the start to the specified column (inclusive)
      splits.add(
        extractArtifact(
          artifactToSplit,
          startingCol,
          0,
          c - startingCol,
          artifactToSplit.rows,
        ),
      );
      startingCol = c + 1;
    }

    // add the right side
    splits.add(
      extractArtifact(
        artifactToSplit,
        startingCol,
        0,
        artifactToSplit.cols - startingCol,
        artifactToSplit.rows,
      ),
    );

    return splits;
  }

  ///
  Artifact extractArtifact(
    Artifact source,
    int left,
    int top,
    int width,
    int height,
  ) {
    IntRect rectLeft = IntRect.fromLTWH(
      left,
      top,
      width,
      height,
    );
    final sub = Artifact.extractSubGrid(matrix: source, rect: rectLeft);
    return Artifact.fromMatrix(sub)..wasPartOfSplit = true;
  }

  /// Identifies and inserts space artifacts between existing artifacts in the band.
  ///
  /// This method analyzes the Kerning between artifacts and inserts space artifacts
  /// where the Kerning exceeds a certain threshold.
  ///
  /// The process involves:
  /// 1. Calculating a threshold Kerning size based on the average width.
  /// 2. Iterating through artifacts to identify Kerning exceeding the threshold.
  /// 3. Creating a list of artifacts that need spaces inserted before them.
  /// 4. Inserting space artifacts at the appropriate positions.
  ///
  /// The threshold is set at 50% of the average width of artifacts in the band.
  void identifySpacesInBand() {
    if (artifacts.isEmpty || artifacts.length <= 1) {
      return;
    }
    final double spaceThreshold = averageWidth * 0.5;

    for (int i = 1; i < artifacts.length; i++) {
      final Artifact leftArtifact = artifacts[i - 1];
      final Artifact rightArtifact = artifacts[i];

      final int leftEdge = leftArtifact.rectFound.right;
      final int rightEdge = rightArtifact.rectFound.left;
      final int gap = rightEdge - leftEdge;

      if (gap >= spaceThreshold) {
        const int borderWidth = 2;
        final int spaceWidth = (gap - (borderWidth * 2)).toInt();
        if (spaceWidth > 1) {
          // this space is big enough
          insertArtifactForSpace(
            artifacts: artifacts,
            insertAtIndex: i,
            cols: spaceWidth,
            rows: rectangleOriginal.height.toInt(),
            locationFoundAt: IntOffset(
              leftArtifact.rectFound.right + 2,
              leftArtifact.rectFound.top,
            ),
          );
          i++;
        }
      }
    }
  }

  /// Inserts a space artifact at a specified position in the artifacts list.
  ///
  /// This method creates a new Artifact representing a space and inserts it
  /// into the artifacts list at the specified index.
  ///
  /// Parameters:
  /// - [insertAtIndex]: The index at which to insert the space artifact.
  /// - [x1]: The left x-coordinate of the space artifact.
  /// - [x2]: The right x-coordinate of the space artifact.
  ///
  /// The created space artifact has the following properties:
  /// - Character matched is a space ' '.
  /// - Band ID is set to the current band's ID.
  /// - Rectangle is set based on the provided x-coordinates and the band's top and bottom.
  /// - A matrix is created based on the dimensions of the rectangle.
  static void insertArtifactForSpace({
    required final List<Artifact> artifacts,
    required final int insertAtIndex,
    required final int cols,
    required final int rows,
    required final IntOffset locationFoundAt,
  }) {
    final Artifact artifactSpace =
        Artifact.fromMatrix(Artifact(cols, rows, false));
    artifactSpace.characterMatched = ' ';
    artifactSpace.locationFound = locationFoundAt;
    artifacts.insert(insertAtIndex, artifactSpace);
  }

  /// Trim the band to fit the inner artifacts
  void trim() {
    if (artifacts.isEmpty) {
      return;
    }

    IntRect boundingBox = IntRect.fromCenter(
      center: this.rectangleAdjusted.center,
      width: 0,
      height: 0,
    );

    for (final Artifact artifact in artifacts) {
      IntRect rectOfContent = artifact.getContentRectAdjusted();
      boundingBox = boundingBox.expandToInclude(rectOfContent);
    }

    int trimTop = (boundingBox.top - this.rectangleAdjusted.top).toInt();

    int trimBottom =
        (this.rectangleAdjusted.bottom - boundingBox.bottom).toInt();

    // now that we have the outer most bounding rect of the content
    // we trim the artifacts
    for (final Artifact artifact in artifacts) {
      artifact.cropBy(top: trimTop, bottom: trimBottom);
    }
  }

  /// Adjusts the positions of artifacts to pack them from left to right.
  ///
  /// This method repositions all artifacts in the band, aligning them
  /// from left to right with proper spacing. It performs the following steps:
  ///
  /// 1. Adds top and bottom padding to each artifact's matrix.
  /// 2. Shifts each artifact horizontally to align with the left edge of the band.
  /// 3. Adjusts the vertical position of each artifact to align with the band's top.
  /// 4. Updates the artifact's rectangle positions.
  /// 5. Increments the left position for the next artifact, including character spacing.
  ///
  /// This method modifies the positions of all artifacts in the band to create
  /// a left-aligned, properly spaced arrangement.
  void packArtifactLeftToRight() {
    int left = this.rectangleOriginal.left;
    int top = artifacts.first.locationFound.y;

    for (final Artifact artifact in artifacts) {
      artifact.locationAdjusted = IntOffset(left, top);

      left += artifact.rectAdjusted.width;
      left += kerningWidth;
    }
  }

  /// Gets the bounding rectangle of this object.
  ///
  /// This getter uses lazy initialization to compute the bounding box
  /// only when first accessed, and then caches the result for subsequent calls.
  ///
  /// Returns:
  ///   A [Rect] representing the bounding box of this object.
  ///
  /// Note: If the object's dimensions or position can change, this cached
  /// value may become outdated. In such cases, consider adding a method
  /// to invalidate the cache when necessary.
  IntRect get rectangleOriginal {
    return getBoundingBox(this.artifacts, useAdjustedRect: false);
  }

  /// Gets the bounding rectangle of this object.
  ///
  /// This getter uses lazy initialization to compute the bounding box
  /// only when first accessed, and then caches the result for subsequent calls.
  ///
  /// Returns:
  ///   A [Rect] representing the bounding box of this object.
  ///
  /// Note: If the object's dimensions or position can change, this cached
  /// value may become outdated. In such cases, consider adding a method
  /// to invalidate the cache when necessary.
  IntRect get rectangleAdjusted {
    return getBoundingBox(this.artifacts, useAdjustedRect: true);
  }

  /// Calculates the bounding rectangle that encloses a list of artifacts.
  ///
  /// This static method takes a list of [Artifact] objects and computes the
  /// minimum and maximum coordinates to define a rectangular bounding box
  /// that contains all the artifacts.
  ///
  /// If the input list is empty, this method returns [Rect.zero].
  ///
  /// Returns:
  ///   A [Rect] representing the bounding box of the provided artifacts.
  static IntRect getBoundingBox(
    final List<Artifact> artifacts, {
    bool useAdjustedRect = true,
  }) {
    if (artifacts.isEmpty) {
      return IntRect();
    }

    int minX = artifacts.first.rectFound.left;
    int minY = artifacts.first.rectFound.top;
    int maxX = artifacts.first.rectFound.right;
    int maxY = artifacts.first.rectFound.bottom;

    for (final Artifact artifact in artifacts) {
      final IntRect rect =
          useAdjustedRect ? artifact.rectAdjusted : artifact.rectFound;
      minX = min(minX, rect.left);
      minY = min(minY, rect.top);
      maxX = max(maxX, rect.right);
      maxY = max(maxY, rect.bottom);
    }

    return IntRect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Returns the count of space characters in the artifacts.
  ///
  /// This getter iterates through all artifacts and counts how many
  /// have a matching character of space ' '. It uses fold to
  /// accumulate the count efficiently.
  ///
  /// Returns:
  ///   An integer representing the total number of space characters.
  int get spacesCount => artifacts.fold(
        0,
        (count, a) => a.characterMatched == ' ' ? count + 1 : count,
      );

  ///
  void padVerticallyArtifactToMatchTheBand() {
    int bandTop = this.rectangleOriginal.top;
    int bandBottom = this.rectangleOriginal.bottom;

    for (final Artifact artifact in artifacts) {
      // Calculate how many rows to pad at the top
      int rowsToPadTop = (artifact.locationFound.y - bandTop).toInt();

      // Calculate how many rows to pad at the bottom
      int rowsToPadBottom =
          (bandBottom - (artifact.locationFound.y + artifact.rows)).toInt();

      // If padding is needed, add empty matrix rows at the top and bottom
      if (rowsToPadTop > 0 || rowsToPadBottom > 0) {
        // Add the empty rows to the artifact matrix
        artifact.padTopBottom(
          paddingTop: rowsToPadTop,
          paddingBottom: rowsToPadBottom,
        );

        // adjust the location found to be the same as the top of the band
        artifact.locationFound = IntOffset(artifact.locationFound.x, bandTop);
      }
    }
  }
}

/// Merges connected artifacts based on specified thresholds.
///
/// This method iterates through the list of artifacts and merges those that are
/// considered connected based on vertical and horizontal thresholds.
///
/// Parameters:
///   [verticalThreshold]: The maximum vertical distance between artifacts to be considered connected.
///   [horizontalThreshold]: The maximum horizontal distance between artifacts to be considered connected.
///
/// Returns:
///   A list of [Artifact] objects after merging connected artifacts.
List<Artifact> mergeConnectedArtifacts({
  required final List<Artifact> artifacts,
  required final double verticalThreshold,
  required final double horizontalThreshold,
}) {
  final List<Artifact> mergedArtifacts = [];

  for (int i = 0; i < artifacts.length; i++) {
    final Artifact current = artifacts[i];

    for (int j = i + 1; j < artifacts.length; j++) {
      final Artifact next = artifacts[j];

      if (areArtifactsConnected(
        current.rectAdjusted,
        next.rectAdjusted,
        verticalThreshold,
        horizontalThreshold,
      )) {
        current.mergeArtifact(next);
        artifacts.removeAt(j);
        j--; // Adjust index since we removed an artifact
      }
    }

    mergedArtifacts.add(current);
  }

  return mergedArtifacts;
}

/// Determines if two artifacts are connected based on their rectangles and thresholds.
///
/// This method checks both horizontal and vertical proximity of the rectangles.
///
/// Parameters:
///   [rect1]: The rectangle of the first artifact.
///   [rect2]: The rectangle of the second artifact.
///   [verticalThreshold]: The maximum vertical distance to be considered connected.
///   [horizontalThreshold]: The maximum horizontal distance to be considered connected.
///
/// Returns:
///   true if the artifacts are considered connected, false otherwise.
bool areArtifactsConnected(
  final IntRect rect1,
  final IntRect rect2,
  final double verticalThreshold,
  final double horizontalThreshold,
) {
  // Calculate the center X of each rectangle
  final double centerX1 = (rect1.left + rect1.right) / 2;
  final double centerX2 = (rect2.left + rect2.right) / 2;

  // Check horizontal connection using the center X values
  final bool horizontallyConnected =
      (centerX1 - centerX2).abs() <= horizontalThreshold;

  // Check vertical connection as before
  final bool verticallyConnected =
      (rect1.bottom + verticalThreshold >= rect2.top &&
          rect1.top - verticalThreshold <= rect2.bottom);

  return horizontallyConnected && verticallyConnected;
}

///
Band rowToBand({
  required final Artifact regionMatrix,
  required final IntOffset offset,
}) {
  //
  // Find the Matrices in the Region
  //
  final List<Artifact> matrixOfPossibleCharacters =
      findMatrices(dilatedMatrixImage: regionMatrix);

  //
  // IntOffset their locations found
  //
  offsetMatrices(
    matrixOfPossibleCharacters,
    offset.x.toInt(),
    offset.y.toInt(),
  );

  //
  // Band
  //
  final Band newBand = Band();
  for (final matrixFound in matrixOfPossibleCharacters) {
    Artifact artifact = Artifact.fromMatrix(matrixFound);

    if (artifact.discardableContent() == false) {
      newBand.addArtifact(artifact);
    }
  }

  newBand.padVerticallyArtifactToMatchTheBand();

  newBand.artifacts = mergeConnectedArtifacts(
    artifacts: newBand.artifacts,
    verticalThreshold: 20,
    horizontalThreshold: 4,
  );

  return newBand;
}

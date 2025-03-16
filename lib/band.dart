import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:textify/artifact.dart';
import 'package:textify/matrix.dart';

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
  double _averageKerning = -1;

  /// Private fields to store calculated average of artifact width
  double _averageWidth = -1;

  /// Gets the average kerning between adjacent artifacts in the band.
  ///
  /// Triggers calculation if not previously computed.
  ///
  /// Returns:
  /// The average kerning as a double, or -1 if there are fewer than 2 artifacts.
  double get averageKerning {
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
  double get averageWidth {
    if ((_averageKerning == -1 || _averageWidth == -1)) {
      _updateStatistics();
    }
    return _averageWidth;
  }

  ///
  void removeEmptyArtifacts() {
    artifacts.removeWhere((artifact) => artifact.matrix.isEmpty);
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
      totalWidth += artifact.matrix.rectAdjusted.width;

      final double kerning = artifact.matrix.rectAdjusted.left -
          artifacts[i - 1].matrix.rectAdjusted.right;
      totalKerning += kerning;
    }
    _averageWidth = totalWidth / count;
    _averageKerning = totalKerning / count;
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
      (a, b) =>
          a.matrix.rectAdjusted.left.compareTo(b.matrix.rectAdjusted.left),
    );
  }

  /// Using the average artifact width, fine the ones that have an outlier width
  /// and tag them needsInspection=true
  void identifySuspiciousLargeArtifacts() {
    final List<Artifact> listToInspect = [];

    final double thresholdWidth = this.averageWidth * 2;

    for (final Artifact artifact in this.artifacts) {
      artifact.needsInspection = artifact.matrix.cols > thresholdWidth;
      if (artifact.needsInspection) {
        listToInspect.add(artifact);
      }
    }
  }

  ///
  static void sortArtifactByRectFound(List<Artifact> list) {
    list.sort((Artifact a, Artifact b) {
      final aCenterY = a.matrix.rectFound.top + a.matrix.rectFound.height / 2;
      final bCenterY = b.matrix.rectFound.top + b.matrix.rectFound.height / 2;
      if ((aCenterY - bCenterY).abs() < 10) {
        return a.matrix.rectFound.left.compareTo(b.matrix.rectFound.left);
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
          artifactToSplit.matrix,
          startingCol,
          0,
          c - startingCol,
          artifactToSplit.matrix.rows,
        ),
      );
      startingCol = c + 1;
    }

    // add the right side
    splits.add(
      extractArtifact(
        artifactToSplit.matrix,
        startingCol,
        0,
        artifactToSplit.matrix.cols - startingCol,
        artifactToSplit.matrix.rows,
      ),
    );

    return splits;
  }

  ///
  Artifact extractArtifact(
    Matrix source,
    int left,
    int top,
    int width,
    int height,
  ) {
    Rect rectLeft = Rect.fromLTWH(
      left.toDouble(),
      top.toDouble(),
      width.toDouble(),
      height.toDouble(),
    );
    final sub = Matrix.extractSubGrid(matrix: source, rect: rectLeft);
    return Artifact.fromMatrix(sub)..wasParOfSplit = true;
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

      final double leftEdge = leftArtifact.matrix.rectFound.right;
      final double rightEdge = rightArtifact.matrix.rectFound.left;
      final double gap = rightEdge - leftEdge;

      if (gap >= spaceThreshold) {
        const int borderWidth = 2;
        final double spaceWidth = gap - (borderWidth * 2);
        if (spaceWidth > 1) {
          // this space is big enough
          insertArtifactForSpace(
            artifacts: artifacts,
            insertAtIndex: i,
            cols: spaceWidth.toInt(),
            rows: rectangleOriginal.height.toInt(),
            locationFoundAt: Offset(
              leftArtifact.matrix.rectFound.right + 2,
              leftArtifact.matrix.rectFound.top,
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
    required final Offset locationFoundAt,
  }) {
    final Artifact artifactSpace =
        Artifact.fromMatrix(Matrix(cols, rows, false));
    artifactSpace.characterMatched = ' ';
    artifactSpace.matrix.locationFound = locationFoundAt;
    artifacts.insert(insertAtIndex, artifactSpace);
  }

  /// Trim the band to fit the inner artifacts
  void trim() {
    if (artifacts.isEmpty) {
      return;
    }

    Rect boundingBox = Rect.fromCenter(
      center: this.rectangleAdjusted.center,
      width: 0,
      height: 0,
    );

    for (final Artifact artifact in artifacts) {
      Rect rectOfContent = artifact.matrix.getContentRectAdjusted();
      boundingBox = boundingBox.expandToInclude(rectOfContent);
    }

    double trimTop = boundingBox.top - this.rectangleAdjusted.top;

    double trimBottom = this.rectangleAdjusted.bottom - boundingBox.bottom;

    // now that we have the outer most bounding rect of the content
    // we trim the artifacts
    for (final Artifact artifact in artifacts) {
      artifact.matrix.cropBy(top: trimTop.toInt(), bottom: trimBottom.toInt());
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
    double left = this.rectangleOriginal.left;
    double top = artifacts.first.matrix.locationFound.dy;

    for (final Artifact artifact in artifacts) {
      artifact.matrix.locationAdjusted = Offset(left, top);

      left += artifact.matrix.rectAdjusted.width;
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
  Rect get rectangleOriginal {
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
  Rect get rectangleAdjusted {
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
  static Rect getBoundingBox(
    final List<Artifact> artifacts, {
    bool useAdjustedRect = true,
  }) {
    if (artifacts.isEmpty) {
      return Rect.zero;
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final Artifact artifact in artifacts) {
      final Rect rect = useAdjustedRect
          ? artifact.matrix.rectAdjusted
          : artifact.matrix.rectFound;
      minX = min(minX, rect.left);
      minY = min(minY, rect.top);
      maxX = max(maxX, rect.right);
      maxY = max(maxY, rect.bottom);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
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
  void paddVerticallyArtrifactToMatchTheBand() {
    double bandTop = this.rectangleOriginal.top;
    double bandBottom = this.rectangleOriginal.bottom;

    for (final Artifact artifact in artifacts) {
      // Calculate how many rows to pad at the top
      int rowsToPadTop = (artifact.matrix.locationFound.dy - bandTop).toInt();

      // Calculate how many rows to pad at the bottom
      int rowsToPadBottom = (bandBottom -
              (artifact.matrix.locationFound.dy + artifact.matrix.rows))
          .toInt();

      // If padding is needed, add empty matrix rows at the top and bottom
      if (rowsToPadTop > 0 || rowsToPadBottom > 0) {
        // Add the empty rows to the artifact matrix
        artifact.matrix.padTopBottom(
          paddingTop: rowsToPadTop,
          paddingBottom: rowsToPadBottom,
        );

        // adjust the location found to be the same as the top of the band
        artifact.matrix.locationFound =
            Offset(artifact.matrix.locationFound.dx, bandTop);
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
        current.matrix.rectAdjusted,
        next.matrix.rectAdjusted,
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
  final Rect rect1,
  final Rect rect2,
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
  required final Matrix regionMatrix,
  required final Offset offset,
}) {
  //
  // Find the Matrices in the Region
  //
  final List<Matrix> matrixOfPossibleCharacters =
      findMatrices(dilatedMatrixImage: regionMatrix);

  //
  // Offset their locations found
  //
  offsetMatrices(
    matrixOfPossibleCharacters,
    offset.dx.toInt(),
    offset.dy.toInt(),
  );

  //
  // Band
  //
  final Band newBand = Band();
  for (final matrixFound in matrixOfPossibleCharacters) {
    Artifact artifact = Artifact.fromMatrix(matrixFound);

    if (artifact.matrix.discardableContent() == false) {
      newBand.addArtifact(artifact);
    }
  }

  newBand.paddVerticallyArtrifactToMatchTheBand();

  newBand.artifacts = mergeConnectedArtifacts(
    artifacts: newBand.artifacts,
    verticalThreshold: 20,
    horizontalThreshold: 4,
  );

  return newBand;
}

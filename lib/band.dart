import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:textify/artifact.dart';
import 'package:textify/int_rect.dart';

export 'package:textify/artifact.dart';

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
      updateStatistics();
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
      updateStatistics();
    }
    return _averageWidth;
  }

  /// Removes all empty artifacts from the band's artifact list.
  ///
  /// An empty artifact is determined by the [Artifact.isEmpty] property.
  /// This method modifies the artifacts list in-place, filtering out any artifacts
  /// that are considered empty.
  void removeEmptyArtifacts() {
    artifacts.removeWhere((artifact) => artifact.isEmpty);
  }

  /// Resets the cached statistics for kerning and width.
  ///
  /// This method sets the average kerning and average width to their default
  /// uninitialized state, forcing recalculation when next accessed.
  void clearStats() {
    _averageKerning = -1;
    _averageWidth = -1;
  }

  /// Calculates the average Kerning between adjacent artifacts and their average width.
  ///
  /// This method computes the mean horizontal distance between the right edge of
  /// one artifact and the left edge of the next artifact in the list. It also
  /// calculates the average width of all artifacts. The artifacts are assumed
  /// to be sorted from left to right.
  ///
  /// If there are fewer than 2 artifacts, both averages are set to -1.
  void updateStatistics() {
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
    clearStats();
  }

  /// Adds all the given artifacts to the band.
  ///
  /// This method adds the provided [artifacts] to the existing list of artifacts in the band.
  /// It also resets the cached rectangle, as the addition or removal of an artifact
  /// can affect the overall layout and dimensions of the band.
  void addArtifacts(final List<Artifact> artifacts) {
    this.artifacts.addAll(artifacts);
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
    List<Artifact> listToInspect = getLargeChunks();

    for (final artifactToSplit in listToInspect) {
      final List<Artifact> artifactsFromColumns = splitChunk(artifactToSplit);
      this.replaceOneArtifactWithMore(artifactToSplit, artifactsFromColumns);
    }
  }

  ///
  List<Artifact> splitChunk(Artifact artifactToSplit) {
    // Get columns where to split the artifact
    List<int> splitColumns = Artifact.getValleysOffsets(artifactToSplit);

    // If no split columns found, return empty list
    if (splitColumns.isEmpty) {
      return [];
    }

    List<Artifact> artifactsFromColumns = Artifact.splitAsColumns(
      artifactToSplit,
      splitColumns,
    );

    return artifactsFromColumns;
  }

  ///
  List<Artifact> getLargeChunks() {
    final List<Artifact> listToInspect = [];

    final double thresholdWidth = this.averageWidth * 2;

    for (final Artifact artifact in this.artifacts) {
      artifact.needsInspection = artifact.cols > thresholdWidth;
      if (artifact.needsInspection) {
        listToInspect.add(artifact);
      }
    }
    return listToInspect;
  }

  ///
  void mergeConnectedArtifactsInPlace() {
    this.artifacts = mergeConnectedArtifacts(
      artifacts: this.artifacts,
      verticalTolerance: this.rectangleOriginal.height,
    );
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
  static List<Artifact> mergeConnectedArtifacts({
    required final List<Artifact> artifacts,
    required final int verticalTolerance,
  }) {
    final List<Artifact> mergedArtifacts = [];

    for (int i = 0; i < artifacts.length; i++) {
      final Artifact current = artifacts[i];

      for (int j = i + 1; j < artifacts.length; j++) {
        final Artifact next = artifacts[j];

        if (areArtifactsOnTheSameColumn(
          current.rectFound,
          next.rectFound,
          verticalTolerance,
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

  ///
  void replaceOneArtifactWithMore(
    final Artifact artifactToReplace,
    final List<Artifact> artifactsToInsert,
  ) {
    int index = this.artifacts.indexOf(artifactToReplace);
    this.artifacts.removeAt(index);
    this.artifacts.insertAll(index, artifactsToInsert);
    clearStats();
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
    this.updateStatistics();

    if (artifacts.isEmpty || artifacts.length <= 1) {
      return;
    }

    // Calculate a more adaptive threshold based on both average width and kerning
    final int spaceThreshold = calculateSpaceThreshold();

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

  /// Calculates an appropriate threshold for determining if a gap should be considered a space
  ///
  /// This method analyzes the distribution of gaps between artifacts to determine
  /// a suitable threshold for identifying spaces.
  ///
  /// Returns:
  /// An integer representing the minimum gap width to be considered a space
  int calculateSpaceThreshold() {
    // A space is typically 1.5-2.5x wider than normal kerning
    return max(_averageKerning * 2, averageWidth ~/ 3);
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
    final Artifact artifactSpace = Artifact.fromMatrix(
      Artifact(cols, rows),
    );
    artifactSpace.characterMatched = ' ';
    artifactSpace.locationFound = locationFoundAt;
    artifacts.insert(insertAtIndex, artifactSpace);
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

  @override
  String toString() {
    String title =
        '[${this.artifacts.length}] Avg(W:${this.averageWidth.toStringAsFixed(0)}, H:${this.rectangleAdjusted.height} G:${this.averageKerning.toStringAsFixed(0)})';

    if (spacesCount > 0) {
      title += ' S[$spacesCount]';
    }

    return title;
  }
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
bool areArtifactsOnTheSameColumn(
  final IntRect rect1,
  final IntRect rect2,
  final int verticalTolerance,
) {
  if (rect1.intersects(rect2)) {
    return true;
  }
  return false;
}

///
Band rowToBand({
  required final Artifact regionMatrix,
  required final IntOffset offset,
}) {
  //
  // Find the Matrices in the Region
  //
  List<Artifact> artifactsFound = findMatrices(
    dilatedMatrixImage: regionMatrix,
  );

  //
  // IntOffset their locations found
  //
  offsetMatrices(
    artifactsFound,
    offset.x.toInt(),
    offset.y.toInt(),
  );

  //
  // Band
  //
  final Band newBand = Band();

  // sort horizontally
  artifactsFound.sort((a, b) => a.locationFound.x.compareTo(b.locationFound.x));

  for (final Artifact artifact in artifactsFound) {
    if (artifact.discardableContent() == false) {
      newBand.addArtifact(artifact);
    }
  }

  // All artifact will have the same grid height
  newBand.padVerticallyArtifactToMatchTheBand();

  // Clean up inner Matrix overlap for example the letter X may have one of the lines not touching the others like so  `/,
  newBand.mergeConnectedArtifactsInPlace();

  newBand.clearStats();

  return newBand;
}

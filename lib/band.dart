import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:textify/artifact.dart';
import 'package:textify/utilities.dart';

export 'package:textify/artifact.dart';

/// Represents a horizontal band (aka strip) in an image/document.
///
/// A Band contains multiple [Artifact] objects and provides methods for
/// analyzing their layout and characteristics.
class Band {
  /// Creates a new Band instance.
  ///
  /// Initializes an empty band with no artifacts.
  Band();

  /// Creates a Band from an artifact region matrix.
  ///
  /// This factory method analyzes a region matrix to find sub-artifacts,
  /// positions them correctly using the provided offset, and creates a new Band
  /// containing these artifacts.
  ///
  /// Parameters:
  ///   [regionMatrix]: The artifact matrix representing a region to analyze.
  ///   [offset]: The position offset to apply to found artifacts.
  ///
  /// Returns:
  ///   A new Band containing the properly positioned and processed artifacts.
  factory Band.splitArtifactIntoBand({
    required final Artifact regionMatrix,
    required final IntOffset offset,
  }) {
    //
    // Find the Matrices in the Region
    //
    List<Artifact> artifactsFound = regionMatrix.findSubArtifacts();

    //
    // IntOffset their locations found
    //
    offsetArtifacts(
      artifactsFound,
      offset.x.toInt(),
      offset.y.toInt(),
    );

    //
    // Band
    //
    final Band newBand = Band();

    // sort horizontally
    artifactsFound
        .sort((a, b) => a.locationFound.x.compareTo(b.locationFound.x));

    for (final Artifact artifact in artifactsFound) {
      if (artifact.discardableContent() == false) {
        newBand.addArtifact(artifact);
      }
    }

    // All artifact will have the same grid height
    newBand.padVerticallyArtifactToMatchTheBand();

    // Clean up inner Matrix overlap for example the letter X may have one of the lines not touching the others like so  `/,
    newBand.mergeArtifactsBasedOnVerticalAlignment();

    newBand.clearStats();

    return newBand;
  }

  /// List of artifacts contained within this band.
  List<Artifact> artifacts = [];

  /// Retrieves the concatenated text from all artifacts in the band.
  ///
  /// Iterates through all artifacts in the band and combines their matched
  /// characters into a single string.
  ///
  /// Returns:
  /// A string containing all the text from the artifacts in this band.
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
  int kerningWidth = 4;

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
    List<Artifact> listToInspect = getWideChunks();

    for (final Artifact artifactToSplit in listToInspect) {
      final List<Artifact> artifactsFromColumns = splitChunk(artifactToSplit);
      this.replaceOneArtifactWithMore(artifactToSplit, artifactsFromColumns);
    }
  }

  /// Splits an artifact into multiple artifacts based on detected valleys.
  ///
  /// This method analyzes the given artifact to find natural splitting points
  /// (valleys in the pixel density) and divides it into multiple artifacts.
  ///
  /// [artifactToSplit] The artifact to be split into multiple components.
  /// Returns a list of new artifacts created from the split.
  List<Artifact> splitChunk(Artifact artifactToSplit) {
    // Get columns where to split the artifact
    List<int> splitColumns = artifactValleysOffsets(artifactToSplit);

    // If no split columns found, return empty list
    if (splitColumns.isEmpty) {
      return [];
    }

    List<Artifact> artifactsFromColumns = splitArtifactByColumns(
      artifactToSplit,
      splitColumns,
    );

    return artifactsFromColumns;
  }

  /// Identifies artifacts that are significantly wider than average.
  ///
  /// This method finds artifacts whose width exceeds twice the average width
  /// of all artifacts in the band, which often indicates merged characters.
  ///
  /// Special cases:
  /// - If there are only 1-2 artifacts of similar width, they are not considered wide
  /// - Width comparison uses a dynamic threshold based on the number of artifacts
  ///
  /// Returns a list of artifacts that are candidates for splitting.
  List<Artifact> getWideChunks() {
    final List<Artifact> listToInspect = [];

    // If we have 0 or 1 artifacts, there's nothing to inspect
    if (artifacts.isEmpty || artifacts.length == 1) {
      return listToInspect;
    }

    // Special case: If we have exactly 2 artifacts with similar widths,
    // don't consider either of them as wide chunks
    if (artifacts.length == 2) {
      final double widthRatio = artifacts[0].cols / artifacts[1].cols;
      // If the width ratio is between 0.7 and 1.3, they're similar enough
      if (widthRatio >= 0.7 && widthRatio <= 1.3) {
        return listToInspect; // Return empty list
      }
    }

    // Calculate threshold based on number of artifacts
    // With fewer artifacts, we need a higher threshold to avoid false positives
    double thresholdMultiplier = 2.0;
    if (artifacts.length <= 3) {
      thresholdMultiplier = 2.5; // More conservative for small sets
    }

    final double thresholdWidth = this.averageWidth * thresholdMultiplier;

    for (final Artifact artifact in this.artifacts) {
      artifact.needsInspection = artifact.cols > thresholdWidth;
      if (artifact.needsInspection) {
        listToInspect.add(artifact);
      }
    }
    return listToInspect;
  }

  /// Merges connected artifacts based on specified thresholds.
  ///
  /// This method iterates through the list of artifacts and merges those that are
  /// considered connected based on vertical and horizontal thresholds.
  ///
  /// The algorithm works by:
  /// 1. Sorting artifacts by their horizontal position
  /// 2. Creating a working copy of the sorted artifacts
  /// 3. For each artifact, checking if it should be merged with any subsequent artifacts
  /// 4. If artifacts should be merged, combining them and removing the merged artifact
  ///
  /// After processing, the band's artifacts list is replaced with the merged artifacts.
  void mergeArtifactsBasedOnVerticalAlignment() {
    final List<Artifact> mergedArtifacts = [];

    // First, sort artifacts by their horizontal position
    final List<Artifact> sortedArtifacts = List.from(artifacts);
    sortedArtifacts
        .sort((a, b) => a.rectFound.left.compareTo(b.rectFound.left));

    // Create a working copy of the artifacts list
    final List<Artifact> workingArtifacts = List.from(sortedArtifacts);

    for (int i = 0; i < workingArtifacts.length; i++) {
      final Artifact current = workingArtifacts[i];

      for (int j = i + 1; j < workingArtifacts.length; j++) {
        final Artifact next = workingArtifacts[j];

        // Check if these artifacts should be merged
        if (shouldMergeArtifacts(current, next)) {
          // current.debugPrintGrid();
          // next.debugPrintGrid();

          current.mergeArtifact(next);
          workingArtifacts.removeAt(j);
          j--; // Adjust index since we removed an artifact
        }
      }

      mergedArtifacts.add(current);
    }

    this.artifacts = mergedArtifacts;
  }

  /// Determines if two artifacts should be merged based on their spatial relationship.
  ///
  /// This method checks if the smaller artifact significantly overlaps with the larger one.
  /// If the smaller artifact has at least 80% overlap with the larger one, they are
  /// considered parts of the same character and should be merged.
  ///
  /// Parameters:
  ///   [artifact1]: The first artifact to check.
  ///   [artifact2]: The second artifact to check.
  ///
  /// Returns:
  ///   true if the artifacts should be merged, false otherwise.
  bool shouldMergeArtifacts(
    final Artifact artifact1,
    final Artifact artifact2,
  ) {
    // Calculate areas to determine which is smaller
    final int area1 = artifact1.rectFound.width * artifact1.rectFound.height;
    final int area2 = artifact2.rectFound.width * artifact2.rectFound.height;

    // Identify smaller and larger artifacts
    final Artifact smaller = area1 <= area2 ? artifact1 : artifact2;
    final Artifact larger = area1 <= area2 ? artifact2 : artifact1;

    // Calculate overlap area
    final IntRect overlap = smaller.rectFound.intersect(larger.rectFound);
    if (overlap.isEmpty) {
      return false;
    }

    final int overlapArea = overlap.width * overlap.height;
    final int smallerArea = smaller.rectFound.width * smaller.rectFound.height;

    // If the smaller artifact overlaps with the larger one by at least 80%,
    // they should be merged
    return overlapArea >= (smallerArea * 0.8);
  }

  /// Replaces a single artifact with multiple artifacts in the band.
  ///
  /// This method removes the specified artifact from the band's artifact list
  /// and inserts the provided list of artifacts at the same position.
  /// It also clears cached statistics since the band's composition has changed.
  ///
  /// Parameters:
  ///   [artifactToReplace]: The artifact to be removed from the band.
  ///   [artifactsToInsert]: The list of artifacts to insert in its place.
  void replaceOneArtifactWithMore(
    final Artifact artifactToReplace,
    final List<Artifact> artifactsToInsert,
  ) {
    int index = this.artifacts.indexOf(artifactToReplace);
    this.artifacts.removeAt(index);
    this.artifacts.insertAll(index, artifactsToInsert);
    clearStats();
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
  /// This method creates a new empty Artifact representing a space character and
  /// inserts it into the provided artifacts list at the specified index.
  ///
  /// Parameters:
  ///   [artifacts]: The list of artifacts to insert the space into.
  ///   [insertAtIndex]: The index at which to insert the space artifact.
  ///   [cols]: The width of the space artifact in columns.
  ///   [rows]: The height of the space artifact in rows.
  ///   [locationFoundAt]: The position where the space artifact should be placed.
  ///
  /// The created space artifact has its [characterMatched] property set to a space ' '
  /// and its location set to the provided [locationFoundAt] coordinates.
  void insertArtifactForSpace({
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

  /// The bounding rectangle that encompasses all artifacts in the band.
  ///
  /// This property calculates the smallest rectangle that contains all artifacts,
  /// adjusted for any transformations.
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

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
  final List<Artifact> artifacts = [];

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
      final double kerning = artifact.matrix.rectAdjusted.left -
          artifacts[i - 1].matrix.rectAdjusted.right;
      totalKerning += kerning;
      totalWidth += artifact.matrix.rectAdjusted.width;
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
  void sortLeftToRight() {
    artifacts.sort(
      (a, b) =>
          a.matrix.rectAdjusted.left.compareTo(b.matrix.rectAdjusted.left),
    );
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
    if (this.artifacts.length <= 2) {
      // nothing to do here
      return;
    }
    final double exceeding = this.averageWidth * 0.75; // in %

    for (int indexOfArtifact = 0;
        indexOfArtifact < this.artifacts.length;
        indexOfArtifact++) {
      if (indexOfArtifact > 0) {
        // Left
        final Artifact artifactLeft = this.artifacts[indexOfArtifact - 1];
        final double x1 = artifactLeft.matrix.rectAdjusted.right;

        // Right
        final Artifact artifactRight = this.artifacts[indexOfArtifact];
        final double x2 = artifactRight.matrix.rectAdjusted.left;

        final double kerning = x2 - x1;

        if (kerning >= exceeding) {
          final int margin = 2;
          // insert Artifact for Space
          insertArtifactForSpace(
            artifacts: this.artifacts,
            insertAtIndex: indexOfArtifact,
            locationFoundAt: Rect.fromLTRB(
              artifactLeft.matrix.rectOriginal.right + margin,
              artifactLeft.matrix.rectOriginal.top,
              artifactRight.matrix.rectOriginal.left - margin,
              artifactRight.matrix.rectOriginal.bottom,
            ),
            locationAdjusted: Rect.fromLTRB(
              artifactLeft.matrix.rectAdjusted.right + margin,
              artifactLeft.matrix.rectAdjusted.top,
              artifactRight.matrix.rectAdjusted.left - margin,
              artifactRight.matrix.rectAdjusted.bottom,
            ),
          );
          indexOfArtifact++;
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
    required final Rect locationFoundAt,
    required final Rect locationAdjusted,
  }) {
    final Artifact artifactSpace = Artifact();
    artifactSpace.characterMatched = ' ';

    artifactSpace.matrix.rectOriginal = locationFoundAt;
    artifactSpace.matrix.rectAdjusted = locationAdjusted;

    artifactSpace.matrix.rectAdjusted = artifactSpace.matrix.rectAdjusted;

    artifactSpace.matrix.setGrid(
      Matrix(
        artifactSpace.matrix.rectAdjusted.width.toInt(),
        artifactSpace.matrix.rectAdjusted.height.toInt(),
      ).data,
    );
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
    double left = this.rectangleAdjusted.left;

    for (final Artifact artifact in artifacts) {
      artifact.matrix.padTopBottom(
        paddingTop:
            (artifact.matrix.rectAdjusted.top - rectangleAdjusted.top).toInt(),
        paddingBottom:
            (rectangleAdjusted.bottom - artifact.matrix.rectAdjusted.bottom)
                .toInt(),
      );

      final double dx = left - artifact.matrix.rectAdjusted.left;
      final double dy =
          rectangleAdjusted.top - artifact.matrix.rectAdjusted.top;
      artifact.matrix.rectAdjusted =
          artifact.matrix.rectAdjusted.shift(Offset(dx, dy));
      artifact.matrix.rectAdjusted = artifact.matrix.rectAdjusted;
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
          : artifact.matrix.rectOriginal;
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
}

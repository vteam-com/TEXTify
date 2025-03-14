// Imports
import 'dart:math';
import 'dart:ui';
import 'package:textify/matrix.dart';

/// Represents an artifact in the text processing system.
///
/// An artifact contains information about a specific character or group of characters,
/// including its position, size, and matrix representation.
class Artifact {
  ///
  Artifact();

  ///
  factory Artifact.fromMatrix(final Matrix matrix) {
    final artifact = Artifact();
    artifact.matrix = matrix;
    return artifact;
  }

  /// The character that this artifact matches.
  String characterMatched = '';

  /// The original matrix representation of the artifact.
  Matrix _matrix = Matrix();

  /// Gets the original matrix representation of the artifact.
  Matrix get matrix => _matrix;

  set matrix(value) {
    _matrix = value;
  }

  /// Gets the vertical profile of the artifact.
  ///
  /// The vertical profile is a `Matrix` that represents the vertical projection
  /// of the artifact's pixels. Each column in the vertical profile matrix
  /// represents a vertical line in the original matrix, with 'on' pixels
  /// indicating the presence of at least one 'on' pixel in that column.
  ///
  /// For example, if the artifact's matrix looks like this:
  ///
  Matrix get verticalHistogram => _matrix.verticalProjection();

  /// The area of the artifact, calculated from its matrix representation.
  int get area => _matrix.area;

  /// Checks if the artifact is empty (contains no 'on' pixels).
  bool get isEmpty {
    return _matrix.isEmpty;
  }

  /// Checks if the artifact is not empty (contains at least one 'on' pixel).
  bool get isNotEmpty {
    return !isEmpty;
  }

  /// Tag the artifact as needs more attentions
  bool needsInspection = false;

  ///
  bool wasParOfSplit = false;

  /// Converts the artifact to a text representation.
  ///
  /// Parameters:
  /// - onChar: The character to use for 'on' pixels (default: '#').
  /// - forCode: Whether the output is intended for code representation (default: false).
  ///
  /// Returns:
  /// A string representation of the artifact.
  String toText({
    final String onChar = '#',
    final bool forCode = false,
  }) {
    return _matrix.gridToString(
      forCode: forCode,
      onChar: onChar,
    );
  }

  /// Merges the current artifact with another artifact.
  ///
  /// This method combines the current artifact with the provided artifact,
  /// creating a new, larger artifact that encompasses both.
  ///
  /// Parameters:
  /// - [toMerge]: The Artifact to be merged with the current artifact.
  ///
  /// The merging process involves:
  /// 1. Creating a new rectangle that encompasses both artifacts.
  /// 2. Creating a new matrix (grid) large enough to contain both artifacts' data.
  /// 3. Copying the data from both artifacts into the new matrix.
  /// 4. Updating the current artifact's matrix and rectangle to reflect the merged state.
  ///
  /// Note: This method modifies the current artifact in-place.
  void mergeArtifact(final Artifact toMerge) {
    // Create a new rectangle that encompasses both artifacts
    final Rect newRect = Rect.fromLTRB(
      min(
        this._matrix.rectAdjusted.left,
        toMerge._matrix.rectAdjusted.left,
      ),
      min(
        this._matrix.rectAdjusted.top,
        toMerge._matrix.rectAdjusted.top,
      ),
      max(
        this._matrix.rectAdjusted.right,
        toMerge._matrix.rectAdjusted.right,
      ),
      max(
        this._matrix.rectAdjusted.bottom,
        toMerge._matrix.rectAdjusted.bottom,
      ),
    );

    // Merge the grids
    final Matrix newGrid = Matrix(newRect.width, newRect.height);

    // Copy both grids onto the new grid
    Matrix.copyGrid(
      this.matrix,
      newGrid,
      (this._matrix.rectAdjusted.left - newRect.left).toInt(),
      (this._matrix.rectAdjusted.top - newRect.top).toInt(),
    );

    Matrix.copyGrid(
      toMerge.matrix,
      newGrid,
      (toMerge._matrix.rectAdjusted.left - newRect.left).toInt(),
      (toMerge._matrix.rectAdjusted.top - newRect.top).toInt(),
    );
    this.matrix.setGrid(newGrid.data);
    // toMerge.matrix.locationFound.left < this.matrix.locationFound.l
    // this.matrix.locationFound = toMerge.matrix.locationFound;
    // this.matrix.locationFound = toMerge.matrix.locationFound;
  }

  /// Returns:
  /// A string representation ths artifact.
  @override
  String toString() {
    return '"$characterMatched" Rect:${_matrix.rectAdjusted.toString()} Area: $area}';
  }
}

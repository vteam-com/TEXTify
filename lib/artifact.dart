// Imports
import 'dart:math';
import 'dart:ui';

import 'package:textify/matrix.dart';

/// Represents an artifact in the text processing system.
///
/// An artifact contains information about a specific character or group of characters,
/// including its position, size, and matrix representation.
class Artifact {
  /// The character that this artifact matches.
  String characterMatched = '';

  /// The original matrix representation of the artifact.
  final Matrix _matrix = Matrix();

  /// Gets the original matrix representation of the artifact.
  Matrix get matrix => _matrix;

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
        this._matrix.rectangle.left,
        toMerge._matrix.rectangle.left,
      ),
      min(
        this._matrix.rectangle.top,
        toMerge._matrix.rectangle.top,
      ),
      max(
        this._matrix.rectangle.right,
        toMerge._matrix.rectangle.right,
      ),
      max(
        this._matrix.rectangle.bottom,
        toMerge._matrix.rectangle.bottom,
      ),
    );

    // Merge the grids
    final Matrix newGrid = Matrix(newRect.width, newRect.height);

    // Copy both grids onto the new grid
    Matrix.copyGrid(
      this.matrix,
      newGrid,
      (this._matrix.rectangle.left - newRect.left).toInt(),
      (this._matrix.rectangle.top - newRect.top).toInt(),
    );

    Matrix.copyGrid(
      toMerge.matrix,
      newGrid,
      (toMerge._matrix.rectangle.left - newRect.left).toInt(),
      (toMerge._matrix.rectangle.top - newRect.top).toInt(),
    );
    this.matrix.setGrid(newGrid.data);
    this.matrix.rectangle =
        this.matrix.rectangle.expandToInclude(toMerge.matrix.rectangle);
  }

  /// Returns:
  /// A string representation ths artifact.
  @override
  String toString() {
    return '"$characterMatched" Rect:${_matrix.rectangle.toString()} Area: $area}';
  }
}

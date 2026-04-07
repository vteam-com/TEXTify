/// This library is part of the Textify package.
/// Provides grid transformation extensions for Artifact: trim, resize,
/// normalize, pad, wrap, extract sub-grids, and merge.
library;

import 'dart:math';

import 'package:textify/artifact.dart';
import 'package:textify/image_helpers.dart';

/// Constants for grid transform operations.
const int _wrapBorderPadding = 1;
const int _wrapBorderPaddingMultiplier = 2;
const double _downscaleDensityLow = 0.2;
const double _downscaleDensityHigh = 0.5;
const double _downscaleFillThresholdMin = 0.25;
const double _downscaleFillThresholdMax = 0.45;
const double _downscaleFillThreshold = 0.3;

/// Extension that adds grid transformation methods to [Artifact].
extension ArtifactGridTransformExt on Artifact {
  /// Trims the matrix by removing empty rows and columns from all sides.
  ///
  /// Returns a new trimmed Artifact, or an empty one if there is no content.
  Artifact trim() {
    if (isEmpty) {
      return Artifact(0, 0);
    }
    // Find the boundaries of the content
    int topRow = 0;
    int bottomRow = rows - 1;
    int leftCol = 0;
    int rightCol = cols - 1;

    // Find top row with content
    while (topRow < rows) {
      bool hasContent = false;
      for (int x = 0; x < cols; x++) {
        if (cellGet(x, topRow)) {
          hasContent = true;
          break;
        }
      }
      if (hasContent) {
        break;
      }
      topRow++;
    }

    // Find bottom row with content
    while (bottomRow > topRow) {
      bool hasContent = false;
      for (int x = 0; x < cols; x++) {
        if (cellGet(x, bottomRow)) {
          hasContent = true;
          break;
        }
      }
      if (hasContent) {
        break;
      }
      bottomRow--;
    }

    // Find left column with content
    outer:
    while (leftCol < cols) {
      for (int y = topRow; y <= bottomRow; y++) {
        if (cellGet(leftCol, y)) {
          break outer;
        }
      }
      leftCol++;
    }

    // Find right column with content
    outer:
    while (rightCol > leftCol) {
      for (int y = topRow; y <= bottomRow; y++) {
        if (cellGet(rightCol, y)) {
          break outer;
        }
      }
      rightCol--;
    }

    // Crop the grid
    final Artifact result = Artifact(
      rightCol - leftCol + 1,
      bottomRow - topRow + 1,
    );
    for (int y = topRow; y <= bottomRow; y++) {
      for (int x = leftCol; x <= rightCol; x++) {
        result.cellSet(x - leftCol, y - topRow, cellGet(x, y));
      }
    }
    return result;
  }

  /// Creates a new Artifact with the specified dimensions by resizing.
  ///
  /// If the current Artifact is punctuation, it will not be cropped
  /// and will be centered in the new Artifact.
  Artifact createNormalizeMatrix(
    final int desiredWidth,
    final int desiredHeight,
  ) {
    // help resizing by ensuring there's a border
    final Artifact source = isPunctuation() ? this : trim();
    final Artifact wrapped = _wrapGridWithFalse(source);
    final double density = wrapped.rows == 0
        ? 0
        : wrapped.countOnPixels() / (wrapped.rows * wrapped.cols);
    final double fillThreshold = _computeDownscaleFillThreshold(density);

    return _resizeGrid(
      wrapped,
      desiredWidth,
      desiredHeight,
      fillThreshold: fillThreshold,
    );
  }

  /// Adds padding to the top and bottom of the matrix.
  void padTopBottom({
    required final int paddingTop,
    required final int paddingBottom,
  }) {
    final int oldRows = rows;
    final Artifact padded = Artifact(
      cols,
      oldRows + paddingTop + paddingBottom,
    );

    for (int y = 0; y < oldRows; y++) {
      for (int x = 0; x < cols; x++) {
        if (cellGet(x, y)) {
          padded.cellSet(x, y + paddingTop, true);
        }
      }
    }

    setGrid(padded.matrix, cols);
  }

  /// Extracts a sub-grid from a larger binary image matrix.
  Artifact extractSubGrid({required final IntRect rect}) {
    final int startX = rect.left.toInt();
    final int startY = rect.top.toInt();
    final int subImageWidth = rect.width.toInt();
    final int subImageHeight = rect.height.toInt();

    final Artifact subImagePixels = Artifact(subImageWidth, subImageHeight);

    for (int x = 0; x < subImageWidth; x++) {
      for (int y = 0; y < subImageHeight; y++) {
        final int sourceX = startX + x;
        final int sourceY = startY + y;

        if (sourceX < cols && sourceY < rows) {
          subImagePixels.cellSet(x, y, cellGet(sourceX, sourceY));
        }
      }
    }

    subImagePixels.locationFound = rect.shift(rectFound.topLeft).topLeft;
    subImagePixels.locationAdjusted = rect.shift(rectAdjusted.topLeft).topLeft;

    return subImagePixels;
  }

  /// Merges the current artifact with another artifact in-place.
  void mergeArtifact(final Artifact toMerge) {
    // Create a new rectangle that encompasses both artifacts
    final IntRect newRect = IntRect.fromLTRB(
      min(rectFound.left, toMerge.rectFound.left),
      min(rectFound.top, toMerge.rectFound.top),
      max(rectFound.right, toMerge.rectFound.right),
      max(rectFound.bottom, toMerge.rectFound.bottom),
    );

    // Create a new grid that can fit both artifacts
    final Artifact newGrid = Artifact(newRect.width, newRect.height);

    // Copy both grids onto the new grid with correct offsets
    Artifact.copyArtifactGrid(
      this,
      newGrid,
      (rectFound.left - newRect.left),
      (rectFound.top - newRect.top),
    );

    Artifact.copyArtifactGrid(
      toMerge,
      newGrid,
      (toMerge.rectFound.left - newRect.left),
      (toMerge.rectFound.top - newRect.top),
    );

    // Update this artifact with the merged data
    setGrid(newGrid.matrix, newGrid.cols);
  }
}

/// Creates a new Artifact with a false border wrapping around it.
Artifact _wrapGridWithFalse(Artifact source) {
  final Artifact newGrid = Artifact(
    source.cols + (_wrapBorderPadding * _wrapBorderPaddingMultiplier),
    source.rows + (_wrapBorderPadding * _wrapBorderPaddingMultiplier),
  );

  for (int y = 0; y < source.rows; y++) {
    for (int x = 0; x < source.cols; x++) {
      newGrid.cellSet(
        x + _wrapBorderPadding,
        y + _wrapBorderPadding,
        source.cellGet(x, y),
      );
    }
  }

  return newGrid;
}

/// Creates a resized version of the given artifact.
Artifact _resizeGrid(
  final Artifact source,
  final int targetWidth,
  final int targetHeight, {
  double fillThreshold = _downscaleFillThreshold,
}) {
  final Artifact resizedGrid = Artifact(targetWidth, targetHeight);

  final double xScale = source.cols / targetWidth;
  final double yScale = source.rows / targetHeight;

  for (int y = 0; y < targetHeight; y++) {
    for (int x = 0; x < targetWidth; x++) {
      final double srcX = x * xScale;
      final double srcY = y * yScale;

      if (targetWidth > source.cols || targetHeight > source.rows) {
        // UpScaling: nearest-neighbor interpolation
        resizedGrid.cellSet(x, y, source.cellGet(srcX.floor(), srcY.floor()));
      } else {
        // DownScaling: threshold-based fill
        final int startX = srcX.floor();
        final int endX = (srcX + xScale).ceil();
        final int startY = srcY.floor();
        final int endY = (srcY + yScale).ceil();

        int blackCount = 0;
        int totalSamples = 0;

        for (int sy = startY; sy < endY && sy < source.rows; sy++) {
          for (int sx = startX; sx < endX && sx < source.cols; sx++) {
            totalSamples++;
            if (source.cellGet(sx, sy)) {
              blackCount++;
            }
          }
        }
        final bool hasBlackPixel =
            totalSamples > 0 && (blackCount / totalSamples) >= fillThreshold;
        resizedGrid.cellSet(x, y, hasBlackPixel);
      }
    }
  }
  return resizedGrid;
}

/// Interpolates a fill threshold for downscaling based on source density.
double _computeDownscaleFillThreshold(double density) {
  if (density <= _downscaleDensityLow) {
    return _downscaleFillThresholdMin;
  }
  if (density >= _downscaleDensityHigh) {
    return _downscaleFillThresholdMax;
  }

  final double t =
      (density - _downscaleDensityLow) /
      (_downscaleDensityHigh - _downscaleDensityLow);
  return _downscaleFillThresholdMin +
      ((_downscaleFillThresholdMax - _downscaleFillThresholdMin) * t);
}

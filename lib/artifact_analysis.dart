/// This library is part of the Textify package.
/// Provides structural analysis: histograms, vertical lines, stems, and strokes.
library;

import 'dart:math';

import 'package:textify/artifact.dart';
import 'package:textify/image_helpers.dart';

/// Constants for analysis operations.
const double _lowerRightStrokeXRatio = 0.55;
const double _lowerRightStrokeYRatio = 0.55;
const double _lowerRightStrokeDensityRatio = 0.6;
const double _stemThresholdRatio = 0.8;
const double _thresholdLinePercentage = 0.7;

/// Which side of the artifact to check for a vertical line.
enum _VerticalLineSide { left, right }

/// Returns the horizontal histogram of the matrix.
///
/// The histogram represents the number of "on" cells in each column.
List<int> _getHistogramHorizontal(Artifact artifact) {
  final List<int> histogram = List.filled(artifact.cols, 0);
  for (int x = 0; x < artifact.cols; x++) {
    for (int y = 0; y < artifact.rows; y++) {
      if (artifact.cellGet(x, y)) {
        histogram[x]++;
      }
    }
  }
  return histogram;
}

/// Returns the vertical histogram of the matrix.
///
/// The histogram represents the number of "on" cells in each row.
List<int> _getHistogramVertical(Artifact artifact) {
  final List<int> histogram = List.filled(artifact.rows, 0);
  for (int y = 0; y < artifact.rows; y++) {
    for (int x = 0; x < artifact.cols; x++) {
      if (artifact.cellGet(x, y)) {
        histogram[y]++;
      }
    }
  }
  return histogram;
}

/// Detects ink density in the lower-right quadrant of the glyph.
///
/// Helps differentiate characters like 'R' from 'P' by checking for
/// a diagonal or lower-right stroke.
bool _hasLowerRightStroke(Artifact artifact) {
  final IntRect content = artifact.getContentRect();
  if (content.isEmpty) {
    return false;
  }

  final int totalOn = artifact.countOnPixels(rect: content);
  final int totalArea = content.width * content.height;
  if (totalOn == 0 || totalArea == 0) {
    return false;
  }

  final int startX =
      content.left + (content.width * _lowerRightStrokeXRatio).round();
  final int startY =
      content.top + (content.height * _lowerRightStrokeYRatio).round();

  final IntRect region = IntRect.fromLTRB(
    startX.clamp(content.left, content.right),
    startY.clamp(content.top, content.bottom),
    content.right,
    content.bottom,
  );

  if (region.isEmpty) {
    return false;
  }

  final int regionOn = artifact.countOnPixels(rect: region);
  final int regionArea = region.width * region.height;
  if (regionArea == 0) {
    return false;
  }

  final double totalDensity = totalOn / totalArea;
  final double regionDensity = regionOn / regionArea;
  return regionDensity >= (totalDensity * _lowerRightStrokeDensityRatio);
}

/// Estimates the number of strong vertical stems in a glyph.
///
/// Useful for disambiguating letters with different stroke counts
/// (e.g., 'u' vs 'm').
int _countVerticalStems(Artifact artifact) {
  final IntRect content = artifact.getContentRect();
  if (content.isEmpty) {
    return 0;
  }

  final int width = content.width;
  final int height = content.height;
  if (width <= 0 || height <= 0) {
    return 0;
  }

  final List<int> histogram = List<int>.filled(width, 0);
  for (int x = 0; x < width; x++) {
    for (int y = 0; y < height; y++) {
      if (artifact.cellGet(content.left + x, content.top + y)) {
        histogram[x]++;
      }
    }
  }

  final int maxCount = histogram.reduce(max);
  if (maxCount == 0) {
    return 0;
  }

  final int threshold = max(1, (maxCount * _stemThresholdRatio).round());

  int stems = 0;
  bool inStem = false;
  for (final int value in histogram) {
    if (value >= threshold) {
      if (!inStem) {
        stems++;
        inStem = true;
      }
    } else {
      inStem = false;
    }
  }

  return stems;
}

/// Checks if the artifact has a vertical line on the left side.
bool hasVerticalLineLeft(Artifact matrix) {
  return _hasVerticalLine(matrix, _VerticalLineSide.left);
}

/// Checks if the artifact has a vertical line on the right side.
bool hasVerticalLineRight(Artifact matrix) {
  return _hasVerticalLine(matrix, _VerticalLineSide.right);
}

/// Shared vertical-line scanner parameterized by side.
bool _hasVerticalLine(Artifact matrix, _VerticalLineSide side) {
  final Artifact visited = Artifact(matrix.cols, matrix.rows);

  final int minVerticalLine = (matrix.rows * _thresholdLinePercentage).toInt();

  final int startX;
  final int endXExclusive;
  final int stepX;

  switch (side) {
    case _VerticalLineSide.left:
      startX = 0;
      endXExclusive = matrix.cols;
      stepX = 1;
    case _VerticalLineSide.right:
      startX = matrix.cols - 1;
      endXExclusive = -1;
      stepX = -1;
  }

  for (int x = startX; x != endXExclusive; x += stepX) {
    for (int y = 0; y < matrix.rows; y++) {
      if (matrix.cellGet(x, y) && !visited.cellGet(x, y)) {
        if (_isValidVerticalLine(
          minVerticalLine: minVerticalLine,
          matrix: matrix,
          x: x,
          y: y,
          visited: visited,
          side: side,
        )) {
          return true;
        }
      }
    }
  }

  return false;
}

/// Shared vertical-line validator parameterized by side.
bool _isValidVerticalLine({
  required final int minVerticalLine,
  required final Artifact matrix,
  required final int x,
  required int y,
  required final Artifact visited,
  required final _VerticalLineSide side,
}) {
  final int rows = matrix.rows;
  int lineLength = 0;

  while (y < rows && matrix.cellGet(x, y)) {
    visited.cellSet(x, y, true);
    lineLength++;

    if (!_isSideOpen(matrix, x, y, side)) {
      lineLength = 0;
    }

    if (lineLength >= minVerticalLine) {
      return true;
    }

    y++;
  }

  return false;
}

/// Checks the open side of a potential vertical line.
///
/// For a left-side line, the pixel to the left must be empty.
/// For a right-side line, the pixel to the right must be empty.
bool _isSideOpen(Artifact m, int x, int y, _VerticalLineSide side) {
  switch (side) {
    case _VerticalLineSide.left:
      if (x - 1 < 0) {
        return true;
      }
      return m.cellGet(x - 1, y) == false;
    case _VerticalLineSide.right:
      if (x + 1 >= m.cols) {
        return true;
      }
      return m.cellGet(x + 1, y) == false;
  }
}

/// Extension that adds analysis convenience methods to [Artifact].
extension ArtifactAnalysisExt on Artifact {
  /// Returns the horizontal histogram of the matrix.
  List<int> getHistogramHorizontal() => _getHistogramHorizontal(this);

  /// Returns the vertical histogram of the matrix.
  List<int> getHistogramVertical() => _getHistogramVertical(this);

  /// Detects ink density in the lower-right quadrant of the glyph.
  bool hasLowerRightStroke() => _hasLowerRightStroke(this);

  /// Estimates the number of strong vertical stems in a glyph.
  int countVerticalStems() => _countVerticalStems(this);

  /// Lazily evaluates and caches vertical line detection on the left side.
  bool get verticalLineLeft =>
      cachedVerticalLineLeft ??= hasVerticalLineLeft(this);

  /// Lazily evaluates and caches vertical line detection on the right side.
  bool get verticalLineRight =>
      cachedVerticalLineRight ??= hasVerticalLineRight(this);
}

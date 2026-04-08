/// This library is part of the Textify package.
/// Provides histogram projection-based segmentation for clean digital text images.
///
/// Uses the XY-cut algorithm: horizontal projection finds text lines,
/// vertical projection finds character segments within each line.
library;

import 'dart:math';

import 'package:textify/artifact.dart';
import 'package:textify/artifact_grid_transform.dart';
import 'package:textify/artifact_splitting.dart' as splitting;
import 'package:textify/image_helpers.dart';

/// Multiplier for median segment width to detect touching characters.
const double _touchingWidthMultiplier = 1.5;

/// Minimum number of artifacts required for space detection.
const int _minArtifactsForSpaces = 2;

/// Minimum number of gaps needed for jump-based threshold.
const int _minGapsForJump = 2;

/// Default minimum space width in pixels.
const int _defaultMinSpaceWidth = 2;

/// Multiplier for jump detection: a gap must be this factor larger.
const double _gapJumpRatio = 1.8;

/// Divisor for computing midpoint between adjacent gaps.
const int _gapMidpointDivisor = 2;

/// Multiplier applied to median gap to estimate space threshold.
const double _medianGapMultiplier = 1.6;

/// Border offset subtracted when sizing space artifacts.
const int _spaceBorderOffset = 2;

/// Minimum number of character segments needed to compute median width.
const int _minSegmentsForMedian = 3;

/// Minimum pixel count in a row/column to consider it non-empty.
const int _minPixelCount = 0;

/// Fraction of peak column density below which a column is treated as empty.
/// Handles stray anti-aliasing pixels in inter-character gaps.
const double _emptyColumnRatio = 0.08;

/// Finds text line rows using horizontal projection (pixel count per row).
///
/// Scans the image row-by-row and groups contiguous non-empty rows into
/// text line regions. Returns [IntRect] regions for each text line, sorted
/// top to bottom.
///
/// For clean digital text, inter-line gaps have zero pixel rows.
List<IntRect> findTextLineRects(Artifact image) {
  if (image.isEmpty) {
    return const [];
  }

  final List<IntRect> lines = [];
  final int width = image.cols;
  final int height = image.rows;

  // Build row histogram
  final List<int> rowHistogram = List<int>.filled(height, 0);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      if (image.cellGet(x, y)) {
        rowHistogram[y]++;
      }
    }
  }

  // For rows, use zero-based threshold: a row is empty only if it truly
  // has no pixels. The adaptive ratio used for columns would incorrectly
  // split lines with descenders (g, p, y) or dots (i, j).
  int lineStart = -1;

  for (int y = 0; y < height; y++) {
    if (rowHistogram[y] > _minPixelCount) {
      // Row has content
      if (lineStart < 0) {
        lineStart = y;
      }
    } else {
      // Blank row
      if (lineStart >= 0) {
        lines.add(IntRect.fromLTWH(0, lineStart, width, y - lineStart));
        lineStart = -1;
      }
    }
  }

  // Close final line if image ends with content
  if (lineStart >= 0) {
    lines.add(IntRect.fromLTWH(0, lineStart, width, height - lineStart));
  }

  return lines;
}

/// Finds character segments within a text line using vertical projection
/// (pixel count per column).
///
/// For clean digital text with separated characters, each character occupies
/// a contiguous range of columns separated by zero-valued column gaps.
///
/// Multi-part characters (i, j, :, ;, !, %, =, ") naturally stay grouped
/// because their components share the same column range.
///
/// When [attemptSplitting] is true, segments significantly wider than the
/// median width are checked for valleys and split if touching characters
/// are detected.
///
/// Returns [IntRect] regions for each character segment, sorted left to right.
List<IntRect> findCharacterRects(
  Artifact image, {
  bool attemptSplitting = true,
}) {
  if (image.isEmpty) {
    return const [];
  }

  final int width = image.cols;
  final int height = image.rows;

  // Build column histogram
  final List<int> colHistogram = List<int>.filled(width, 0);
  for (int x = 0; x < width; x++) {
    for (int y = 0; y < height; y++) {
      if (image.cellGet(x, y)) {
        colHistogram[x]++;
      }
    }
  }

  // Adaptive threshold: columns with very few pixels are treated as empty.
  // This handles stray anti-aliasing pixels in inter-character gaps.
  int maxCol = 0;
  for (int x = 0; x < width; x++) {
    if (colHistogram[x] > maxCol) {
      maxCol = colHistogram[x];
    }
  }
  final int emptyThreshold = max(1, (maxCol * _emptyColumnRatio).floor());

  // Find contiguous column ranges with pixel density above the threshold
  final List<IntRect> segments = [];
  int segStart = -1;

  for (int x = 0; x < width; x++) {
    if (colHistogram[x] >= emptyThreshold) {
      if (segStart < 0) {
        segStart = x;
      }
    } else {
      if (segStart >= 0) {
        segments.add(IntRect.fromLTWH(segStart, 0, x - segStart, height));
        segStart = -1;
      }
    }
  }

  // Close final segment
  if (segStart >= 0) {
    segments.add(IntRect.fromLTWH(segStart, 0, width - segStart, height));
  }

  if (!attemptSplitting || segments.length < _minSegmentsForMedian) {
    return segments;
  }

  // Split touching characters: segments wider than threshold
  return _splitTouchingSegments(image, segments);
}

/// Splits segments that are significantly wider than the median width.
///
/// Uses valley detection on the sub-image histogram to find split points.
List<IntRect> _splitTouchingSegments(Artifact image, List<IntRect> segments) {
  // Compute median segment width
  final List<int> widths = segments.map((r) => r.width).toList()..sort();
  final int medianWidth = widths[widths.length ~/ 2];
  final int touchingThreshold = (medianWidth * _touchingWidthMultiplier)
      .round();

  final List<IntRect> result = [];

  for (final IntRect seg in segments) {
    if (seg.width <= touchingThreshold) {
      result.add(seg);
      continue;
    }

    // Extract sub-image for this segment
    final Artifact subImage = image.extractSubGrid(rect: seg);

    // Use existing valley detection to find split points
    final List<int> valleys = splitting.artifactValleysOffsets(
      subImage,
      allowSoftValleys: true,
    );

    if (valleys.isEmpty) {
      result.add(seg);
      continue;
    }

    // Split at valleys and create sub-segments
    final List<Artifact> pieces = splitting.splitArtifactByColumns(
      subImage,
      valleys,
    );

    for (final Artifact piece in pieces) {
      if (piece.isEmpty) {
        continue;
      }
      final IntRect contentRect = piece.getContentRect();
      if (contentRect.isEmpty) {
        continue;
      }
      result.add(
        IntRect.fromLTWH(
          seg.left + piece.locationFound.x,
          seg.top,
          piece.cols,
          seg.height,
        ),
      );
    }
  }

  return result;
}

/// Inserts space artifacts between character artifacts where the gap between
/// them exceeds a threshold computed from the gap distribution.
///
/// [artifacts] is modified in place with space artifacts inserted.
/// [lineHeight] is the height of the text line for sizing space artifacts.
void insertSpacesByGap(List<Artifact> artifacts, int lineHeight) {
  if (artifacts.length < _minArtifactsForSpaces) {
    return;
  }

  // Collect all gaps
  final List<int> gaps = [];
  for (int i = 1; i < artifacts.length; i++) {
    final int gap =
        artifacts[i].rectFound.left - artifacts[i - 1].rectFound.right;
    if (gap > 0) {
      gaps.add(gap);
    }
  }

  if (gaps.isEmpty) {
    return;
  }

  // Compute space threshold from gap distribution
  gaps.sort();
  final int spaceThreshold = _computeSpaceThreshold(gaps);

  // Insert space artifacts
  for (int i = 1; i < artifacts.length; i++) {
    final int gap =
        artifacts[i].rectFound.left - artifacts[i - 1].rectFound.right;
    if (gap >= spaceThreshold) {
      final int spaceWidth = max(1, gap - _spaceBorderOffset);
      final Artifact spaceArtifact = Artifact(spaceWidth, lineHeight);
      spaceArtifact.matchingCharacter = ' ';
      spaceArtifact.locationFound = IntOffset(
        artifacts[i - 1].rectFound.right + 1,
        artifacts[i - 1].rectFound.top,
      );
      artifacts.insert(i, spaceArtifact);
      i++; // Skip the inserted space
    }
  }
}

/// Computes a space threshold from sorted gap list.
///
/// Uses jump detection or median-based fallback.
int _computeSpaceThreshold(List<int> sortedGaps) {
  if (sortedGaps.length < _minGapsForJump) {
    return sortedGaps.isEmpty
        ? _defaultMinSpaceWidth
        : max(_defaultMinSpaceWidth, sortedGaps.first + 1);
  }

  // Look for a clear jump in gap sizes
  double bestRatio = 1.0;
  int bestIndex = -1;

  for (int i = 1; i < sortedGaps.length; i++) {
    final int prev = sortedGaps[i - 1];
    if (prev <= 0) {
      continue;
    }
    final double ratio = sortedGaps[i] / prev;
    if (ratio > bestRatio) {
      bestRatio = ratio;
      bestIndex = i;
    }
  }

  if (bestIndex >= 0 && bestRatio >= _gapJumpRatio) {
    return ((sortedGaps[bestIndex - 1] + sortedGaps[bestIndex]) /
            _gapMidpointDivisor)
        .round();
  }

  // Fallback: median × multiplier
  final int median = sortedGaps[sortedGaps.length ~/ _gapMidpointDivisor];
  return max(_defaultMinSpaceWidth, (median * _medianGapMultiplier).round());
}

/// This library is part of the Textify package.
/// Provides valley detection and artifact splitting utilities.
library;

import 'dart:math';

import 'package:textify/artifact.dart';
import 'package:textify/artifact_analysis.dart';
import 'package:textify/image_helpers.dart';

/// Constants for valley detection and splitting.
const int _minHistogramLengthForValley = 3;
const int _invalidThreshold = -1;
const int _flatValleyLookahead = 2;
const int _valleyPeakWindow = 2;
const double _valleyDepthRatio = 0.4;
const int _minSplitSeparation = 2;
const int _splitMidpointDivisor = 2;
const double _valleyThresholdMultiplier = 1.2;

/// Returns a list of column indices where the artifact should be split.
///
/// This method analyzes the horizontal histogram of the artifact to identify
/// valleys (columns with fewer pixels) that are good candidates for splitting.
///
/// If all columns have identical values (no valleys or peaks), returns an empty
/// list indicating no splitting is needed.
List<int> artifactValleysOffsets(
  final Artifact artifact, {
  bool allowSoftValleys = true,
}) {
  final List<int> peaksAndValleys = artifact.getHistogramHorizontal();

  // Check if all columns have identical values
  final bool allIdentical = peaksAndValleys.every(
    (value) => value == peaksAndValleys[0],
  );
  if (allIdentical) {
    // no valleys
    return [];
  }

  final List<int> offsets = [];

  // Calculate a more appropriate threshold for large artifacts
  final int threshold = calculateThreshold(peaksAndValleys);

  final List<List<int>> gaps = [];

  if (threshold != _invalidThreshold) {
    // Find columns where the pixel count is below the threshold
    List<int> currentGap = [];

    // Identify gaps (consecutive columns below threshold)
    for (int i = 0; i < peaksAndValleys.length; i++) {
      if (peaksAndValleys[i] <= threshold) {
        currentGap.add(i);
      } else if (currentGap.isNotEmpty) {
        gaps.add(List.from(currentGap));
        currentGap = [];
      }
    }

    // Add the last gap if it exists
    if (currentGap.isNotEmpty) {
      gaps.add(currentGap);
    }
  }

  // Add soft valleys for touching letters (no empty column),
  // but only when the valley is significantly lower than nearby peaks.
  if (allowSoftValleys) {
    final List<int> softValleys = _findSoftValleySplits(peaksAndValleys);
    for (final int index in softValleys) {
      gaps.add([index]);
    }
  }

  // Filter out gaps that are at the edges of the artifact
  // These are likely serifs or other character features, not actual gaps between characters
  gaps.removeWhere((gap) {
    if (gap.first == 0) {
      return true;
    }
    if (gap.last == peaksAndValleys.length - 1) {
      return true;
    }
    return false;
  });

  // Sort the gaps by position (ascending) to maintain left-to-right order
  gaps.sort((a, b) => a[0].compareTo(b[0]));

  // For each gap, use the middle of the gap as the split column
  for (final List<int> gap in gaps) {
    if (gap.isNotEmpty) {
      final int splitPoint = gap.first + (gap.length ~/ 2);
      offsets.add(splitPoint);
    }
  }

  return _dedupeSplitOffsets(offsets);
}

/// Splits the given artifact into multiple column slices based on the offsets.
///
/// Each entry in [offsets] marks the start column of a new slice.
/// Returns a list of [Artifact] objects, where each slice represents
/// a vertical portion of the original [artifactToSplit] while maintaining
/// its relative position.
List<Artifact> splitArtifactByColumns(
  final Artifact artifactToSplit,
  List<int> offsets,
) {
  List<Artifact> result = [];

  // Handle the first segment (from 0 to first offset)
  if (offsets.isNotEmpty && offsets[0] > 0) {
    Artifact firstSegment = Artifact(offsets[0], artifactToSplit.rows);

    // Copy the relevant columns
    for (int x = 0; x < offsets[0]; x++) {
      for (int y = 0; y < artifactToSplit.rows; y++) {
        firstSegment.cellSet(x, y, artifactToSplit.cellGet(x, y));
      }
    }

    // Set location properties
    firstSegment.locationFound = IntOffset(
      artifactToSplit.locationFound.x,
      artifactToSplit.locationFound.y,
    );

    firstSegment.locationAdjusted = IntOffset(
      artifactToSplit.locationAdjusted.x,
      artifactToSplit.locationAdjusted.y,
    );

    firstSegment.wasPartOfSplit = true;
    result.add(firstSegment);
  }

  // Handle middle segments and last segment
  for (int i = 0; i < offsets.length; i++) {
    int columnStart = offsets[i];
    int columnEnd = (i < offsets.length - 1)
        ? offsets[i + 1]
        : artifactToSplit.cols;

    // Skip if this segment has no width
    if (columnEnd <= columnStart) {
      continue;
    }

    // Create segment
    Artifact segment = Artifact(columnEnd - columnStart, artifactToSplit.rows);

    // Copy the relevant columns
    for (int x = columnStart; x < columnEnd; x++) {
      for (int y = 0; y < artifactToSplit.rows; y++) {
        segment.cellSet(x - columnStart, y, artifactToSplit.cellGet(x, y));
      }
    }

    // Set location properties
    segment.locationFound = IntOffset(
      artifactToSplit.locationFound.x + columnStart,
      artifactToSplit.locationFound.y,
    );

    segment.locationAdjusted = IntOffset(
      artifactToSplit.locationAdjusted.x + columnStart,
      artifactToSplit.locationAdjusted.y,
    );

    segment.wasPartOfSplit = true;
    result.add(segment);
  }

  return result;
}

/// Calculates an appropriate threshold for identifying valleys in a histogram.
///
/// This function finds the smallest valleys (local minima) in the histogram,
/// which represent the gaps between characters.
///
/// Returns an integer threshold value, or a sentinel value if a valid threshold
/// couldn't be determined.
int calculateThreshold(List<int> histogram) {
  // Need at least a minimum number of elements to have a valley.
  if (histogram.length >= _minHistogramLengthForValley) {
    // Find all valleys (local minima)
    List<int> valleys = [];

    // Handle single-point valleys
    for (int i = 1; i < histogram.length - 1; i++) {
      if (histogram[i] < histogram[i - 1] && histogram[i] < histogram[i + 1]) {
        valleys.add(histogram[i]);
      }
    }

    // Handle flat valleys (consecutive identical values that are lower than neighbors)
    for (int i = 1; i < histogram.length - _flatValleyLookahead; i++) {
      // Check if we have a sequence of identical values
      if (histogram[i] == histogram[i + 1]) {
        // Find the end of this flat region
        int j = i + 1;
        while (j < histogram.length - 1 && histogram[j] == histogram[i]) {
          j++;
        }

        // Check if this flat region is a valley (lower than both neighbors)
        if (i > 0 &&
            j < histogram.length &&
            histogram[i] < histogram[i - 1] &&
            histogram[i] < histogram[j]) {
          valleys.add(histogram[i]);
        }

        // Skip to the end of this flat region
        i = j - 1;
      }
    }

    // If we found valleys, use the smallest one as threshold
    if (valleys.isNotEmpty) {
      int smallestValley = valleys.reduce(min);
      return (smallestValley * _valleyThresholdMultiplier)
          .toInt(); // Slightly higher than smallest valley
    }
  }
  // If no valleys found, return the invalid threshold sentinel.
  return _invalidThreshold;
}

/// Finds shallow valley candidates when no zero-height gaps exist.
List<int> _findSoftValleySplits(List<int> histogram) {
  if (histogram.length < _minHistogramLengthForValley) {
    return const [];
  }

  final List<int> splits = [];
  int i = 1;
  while (i < histogram.length - 1) {
    if (histogram[i] > histogram[i - 1] || histogram[i] > histogram[i + 1]) {
      i++;
      continue;
    }

    int start = i;
    int end = i;
    while (end + 1 < histogram.length &&
        histogram[end + 1] == histogram[start]) {
      end++;
    }

    if (_isDeepValley(histogram, start, end)) {
      final int mid = start + ((end - start) ~/ _splitMidpointDivisor);
      splits.add(mid);
    }

    i = end + 1;
  }

  return splits;
}

/// Returns true when a valley is sufficiently lower than nearby peaks.
bool _isDeepValley(List<int> histogram, int start, int end) {
  final int leftStart = max(0, start - _valleyPeakWindow);
  final int leftEnd = max(0, start - 1);
  final int rightStart = min(histogram.length - 1, end + 1);
  final int rightEnd = min(histogram.length - 1, end + _valleyPeakWindow);

  final int leftPeak = _maxInRange(histogram, leftStart, leftEnd);
  final int rightPeak = _maxInRange(histogram, rightStart, rightEnd);

  if (leftPeak == 0 || rightPeak == 0) {
    return false;
  }

  final int minPeak = min(leftPeak, rightPeak);
  final int valley = histogram[start];
  return valley <= (minPeak * _valleyDepthRatio).round();
}

/// Returns the maximum histogram value in an inclusive index range.
int _maxInRange(List<int> histogram, int start, int end) {
  if (start > end) {
    return 0;
  }
  int maxValue = histogram[start];
  for (int i = start + 1; i <= end; i++) {
    if (histogram[i] > maxValue) {
      maxValue = histogram[i];
    }
  }
  return maxValue;
}

/// Sorts split offsets and removes entries that are too close together.
List<int> _dedupeSplitOffsets(List<int> offsets) {
  if (offsets.isEmpty) {
    return offsets;
  }

  offsets.sort();
  final List<int> deduped = [offsets.first];
  for (int i = 1; i < offsets.length; i++) {
    final int current = offsets[i];
    if (current - deduped.last >= _minSplitSeparation) {
      deduped.add(current);
    }
  }
  return deduped;
}

/// This library is part of the Textify package.
/// Provides morphological operations: dilation, erosion, and decorative element removal.
library;

import 'dart:math';

import 'package:textify/artifact.dart';
import 'package:textify/artifact_region.dart';
import 'package:textify/image_helpers.dart';

/// Constants for morphological operations.
const int _erosionNeighborThreshold = 5;
const double _decorativeLineCoverageRatio = 0.12;
const double _decorativeLineThicknessRatio = 0.02;
const int _decorativeLineMinThickness = 6;
const double _decorativeBlobCoverageRatio = 0.12;
const double _decorativeBlobAreaRatio = 0.02;
const double _decorativeBlobDensityMin = 0.65;

/// Applies dilation morphological operation to a binary image.
///
/// Dilation expands the white regions in a binary image, which helps connect
/// nearby text elements and fill small gaps in characters.
Artifact dilateArtifact({
  required final Artifact matrixImage,
  required int kernelSize,
}) {
  final Artifact result = Artifact(matrixImage.cols, matrixImage.rows);
  final int halfKernel = kernelSize ~/ 2;
  final int width = matrixImage.cols;
  final int height = matrixImage.rows;

  // Pre-compute row boundaries for each y position
  final List<int> minKYs = List<int>.filled(height, 0);
  final List<int> maxKYs = List<int>.filled(height, 0);
  for (int y = 0; y < height; y++) {
    minKYs[y] = max(0, y - halfKernel);
    maxKYs[y] = min(height - 1, y + halfKernel);
  }

  // Pre-compute column boundaries for each x position
  final List<int> minKXs = List<int>.filled(width, 0);
  final List<int> maxKXs = List<int>.filled(width, 0);
  for (int x = 0; x < width; x++) {
    minKXs[x] = max(0, x - halfKernel);
    maxKXs[x] = min(width - 1, x + halfKernel);
  }

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      if (matrixImage.cellGet(x, y)) {
        for (int ky = minKYs[y]; ky <= maxKYs[y]; ky++) {
          for (int kx = minKXs[x]; kx <= maxKXs[x]; kx++) {
            result.cellSet(kx, ky, true);
          }
        }
      }
    }
  }

  return result;
}

/// Creates a softly eroded version of an artifact to reduce stroke thickness.
///
/// A pixel remains "on" only if it has at least [_erosionNeighborThreshold]
/// neighbors (including itself) in a 3x3 window.
Artifact _erodeSoft(Artifact source) {
  final Artifact result = Artifact(source.cols, source.rows);
  if (source.isEmpty) {
    return result;
  }

  for (int y = 0; y < source.rows; y++) {
    for (int x = 0; x < source.cols; x++) {
      if (!source.cellGet(x, y)) {
        continue;
      }

      int neighbors = 0;
      for (int dy = -1; dy <= 1; dy++) {
        final int ny = y + dy;
        if (ny < 0 || ny >= source.rows) {
          continue;
        }
        for (int dx = -1; dx <= 1; dx++) {
          final int nx = x + dx;
          if (nx < 0 || nx >= source.cols) {
            continue;
          }
          if (source.cellGet(nx, ny)) {
            neighbors++;
          }
        }
      }

      if (neighbors >= _erosionNeighborThreshold) {
        result.cellSet(x, y, true);
      }
    }
  }

  return result;
}

/// Returns a copy with very long decorative line components removed.
///
/// This strips non-text rulers/borders that often connect distant regions
/// during dilation and hurt OCR segmentation.
Artifact _removeDecorativeLineComponents(Artifact source) {
  if (source.isEmpty) {
    return Artifact.fromMatrix(source);
  }

  final Artifact cleaned = Artifact.fromMatrix(source);
  final List<Artifact> components = source.findSubArtifacts();

  final int minHorizontalCoverage = (source.cols * _decorativeLineCoverageRatio)
      .round();
  final int minVerticalCoverage = (source.rows * _decorativeLineCoverageRatio)
      .round();
  final int maxThickness = max(
    _decorativeLineMinThickness,
    (min(source.cols, source.rows) * _decorativeLineThicknessRatio).round(),
  );
  final int minBlobWidth = (source.cols * _decorativeBlobCoverageRatio).round();
  final int minBlobHeight = (source.rows * _decorativeBlobCoverageRatio)
      .round();
  final int minBlobArea = (source.cols * source.rows * _decorativeBlobAreaRatio)
      .round();

  for (final Artifact component in components) {
    final IntRect rect = component.rectFound;
    final bool longHorizontal =
        rect.width >= minHorizontalCoverage && rect.height <= maxThickness;
    final bool longVertical =
        rect.height >= minVerticalCoverage && rect.width <= maxThickness;
    bool shouldRemove =
        component.isConsideredLine() && (longHorizontal || longVertical);

    if (!shouldRemove) {
      final int boundingArea = rect.width * rect.height;
      final bool largeBlob =
          rect.width >= minBlobWidth &&
          rect.height >= minBlobHeight &&
          boundingArea >= minBlobArea;

      if (largeBlob) {
        int onPixels = 0;
        for (int y = 0; y < component.rows; y++) {
          for (int x = 0; x < component.cols; x++) {
            if (component.cellGet(x, y)) {
              onPixels++;
            }
          }
        }

        final double fillRatio = boundingArea == 0
            ? 0
            : onPixels / boundingArea;
        if (fillRatio >= _decorativeBlobDensityMin) {
          shouldRemove = true;
        }
      }
    }

    if (!shouldRemove) {
      continue;
    }

    final int offsetX = component.locationFound.x;
    final int offsetY = component.locationFound.y;
    for (int y = 0; y < component.rows; y++) {
      for (int x = 0; x < component.cols; x++) {
        if (!component.cellGet(x, y)) {
          continue;
        }
        cleaned.cellSet(offsetX + x, offsetY + y, false);
      }
    }
  }

  return cleaned;
}

/// Extension that adds morphological convenience methods to [Artifact].
extension ArtifactMorphologyExt on Artifact {
  /// Creates a softly eroded version of this artifact.
  Artifact erodeSoft() => _erodeSoft(this);

  /// Returns a copy with very long decorative line components removed.
  Artifact removeDecorativeLineComponents() =>
      _removeDecorativeLineComponents(this);
}

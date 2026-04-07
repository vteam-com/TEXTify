/// This library is part of the Textify package.
/// Provides flood-fill, sub-region detection, and enclosure counting for Artifacts.
library;

import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:textify/artifact.dart';
import 'package:textify/image_helpers.dart';

/// Constants for region detection.
const int _minEnclosedRegionSize = 3;
const double _minEnclosedRegionAreaRatio = 0.01;
const int _pixelOnValue = 1;
const int _pixelOffValue = 0;

/// Performs a highly optimized flood fill algorithm on a binary image matrix.
///
/// Uses direct array access and efficient data structures (8-connected).
///
/// Returns a list of [Point] objects representing all connected points found.
List<Point<int>> floodFill(
  final Artifact binaryPixels,
  final Artifact visited,
  final int startX,
  final int startY,
) {
  final int width = binaryPixels.cols;
  final int height = binaryPixels.rows;

  // Early bounds check
  if (startX < 0 || startX >= width || startY < 0 || startY >= height) {
    return const [];
  }

  // Early check for valid starting pixel
  if (!binaryPixels.cellGet(startX, startY)) {
    return const [];
  }

  // Direct access to the underlying arrays
  final Uint8List pixelData = binaryPixels.matrix;
  final Uint8List visitedData = visited.matrix;

  // Pre-allocate with estimated capacity to reduce reallocations
  final List<Point<int>> connectedPoints = <Point<int>>[];
  final Queue<int> queue = Queue<int>();

  // Calculate initial index
  final int startIndex = startY * width + startX;

  // Mark start point as visited and add to queue
  visitedData[startIndex] = _pixelOnValue;
  queue.add(startIndex);
  connectedPoints.add(Point(startX, startY));

  // Direction offsets for adjacent pixels (including diagonals)
  const List<int> rowOffsets = [-1, -1, -1, 0, 0, 1, 1, 1];
  const List<int> colOffsets = [-1, 0, 1, -1, 1, -1, 0, 1];

  while (queue.isNotEmpty) {
    final int currentIndex = queue.removeFirst();
    final int x = currentIndex % width;
    final int y = currentIndex ~/ width;

    // Check all eight directions (including diagonals)
    for (int i = 0; i < rowOffsets.length; i++) {
      final int nx = x + colOffsets[i];
      final int ny = y + rowOffsets[i];

      // Skip out-of-bounds
      if (nx < 0 || nx >= width || ny < 0 || ny >= height) {
        continue;
      }

      final int neighborIndex = ny * width + nx;

      // Check if neighbor is valid and not visited
      if (pixelData[neighborIndex] == _pixelOnValue &&
          visitedData[neighborIndex] == _pixelOffValue) {
        visitedData[neighborIndex] = _pixelOnValue;
        queue.add(neighborIndex);
        connectedPoints.add(Point(nx, ny));
      }
    }
  }

  return connectedPoints;
}

/// Performs a flood fill algorithm and directly calculates the bounding rectangle
/// without storing all individual points (4-connected).
///
/// Returns an [IntRect] representing the bounding rectangle of the connected region.
IntRect floodFillToRect(
  final Artifact binaryPixels,
  final Artifact visited,
  final int startX,
  final int startY,
) {
  final int width = binaryPixels.cols;
  final int height = binaryPixels.rows;

  // Initialize bounds to starting point
  int minX = startX;
  int minY = startY;
  int maxX = startX;
  int maxY = startY;

  // Early bounds check
  if (startX >= 0 && startX < width && startY >= 0 && startY < height) {
    // Early check for valid starting pixel
    if (binaryPixels.cellGet(startX, startY)) {
      // Direct access to the underlying arrays
      final Uint8List pixelData = binaryPixels.matrix;
      final Uint8List visitedData = visited.matrix;

      final Queue<int> queue = Queue<int>();

      // Calculate initial index
      final int startIndex = startY * width + startX;

      // Mark start point as visited and add to queue
      visitedData[startIndex] = _pixelOnValue;
      queue.add(startIndex);

      // Direction offsets for adjacent pixels
      const List<int> rowOffsets = [0, 0, -1, 1];
      const List<int> colOffsets = [-1, 1, 0, 0];

      while (queue.isNotEmpty) {
        final int currentIndex = queue.removeFirst();
        final int x = currentIndex % width;
        final int y = currentIndex ~/ width;

        // Update bounds
        minX = min(minX, x);
        minY = min(minY, y);
        maxX = max(maxX, x);
        maxY = max(maxY, y);

        // Check all four directions
        for (int i = 0; i < rowOffsets.length; i++) {
          final int nx = x + colOffsets[i];
          final int ny = y + rowOffsets[i];

          // Skip out-of-bounds
          if (nx < 0 || nx >= width || ny < 0 || ny >= height) {
            continue;
          }

          final int neighborIndex = ny * width + nx;

          // Check if neighbor is valid and not visited
          if (pixelData[neighborIndex] == _pixelOnValue &&
              visitedData[neighborIndex] == _pixelOffValue) {
            visitedData[neighborIndex] = _pixelOnValue;
            queue.add(neighborIndex);
          }
        }
      }
    }
  }

  // Calculate width and height
  final int regionWidth = maxX - minX + 1;
  final int regionHeight = maxY - minY + 1;

  return IntRect.fromLTWH(minX, minY, regionWidth, regionHeight);
}

/// Identifies distinct regions in a binary image.
///
/// Uses flood fill to find connected components and returns their bounding boxes.
/// The returned list is sorted using [Artifact.sortRectangles].
List<IntRect> _findSubRegions(Artifact artifact) {
  List<IntRect> regions = [];

  final Artifact visited = Artifact(artifact.cols, artifact.rows);

  final int width = artifact.cols;
  final int height = artifact.rows;
  final Uint8List imageData = artifact.matrix;
  final Uint8List visitedData = visited.matrix;

  // Scan through each pixel - use direct array access
  for (int y = 0; y < height; y++) {
    final int rowOffset = y * width;
    for (int x = 0; x < width; x++) {
      final int index = rowOffset + x;
      if (visitedData[index] == _pixelOffValue &&
          imageData[index] == _pixelOnValue) {
        final IntRect rect = floodFillToRect(artifact, visited, x, y);

        if (rect.width > 0 && rect.height > 0) {
          regions.add(rect);
        }
      }
    }
  }

  Artifact.sortRectangles(regions);
  return regions;
}

/// Finds the connected components (artifacts) in a binary image matrix.
///
/// Each connected region is converted to a separate [Artifact] using the
/// [Artifact.fromPoints] factory method.
List<Artifact> _findSubArtifacts(Artifact artifact) {
  List<Artifact> regions = [];

  final Artifact visited = Artifact(artifact.cols, artifact.rows);

  for (int y = 0; y < artifact.rows; y++) {
    for (int x = 0; x < artifact.cols; x++) {
      if (!visited.cellGet(x, y) && artifact.cellGet(x, y)) {
        final List<Point<int>> connectedPoints = floodFill(
          artifact,
          visited,
          x,
          y,
        );

        if (connectedPoints.isEmpty) {
          continue;
        }
        regions.add(Artifact.fromPoints(connectedPoints));
      }
    }
  }

  Artifact.sortMatrices(regions);
  return regions;
}

/// Counts the number of enclosed regions in a given grid.
///
/// An enclosed region is a contiguous area of false cells completely
/// surrounded by true cells. This is useful for character recognition:
/// e.g. 'O' has one enclosed region, 'B' has two.
int countEnclosedRegions(final Artifact grid) {
  final int rows = grid.rows;
  final int cols = grid.cols;

  final Artifact visited = Artifact(cols, rows);

  int loopCount = 0;

  for (int y = 0; y < rows; y++) {
    for (int x = 0; x < cols; x++) {
      if (!grid.cellGet(x, y) && !visited.cellGet(x, y)) {
        int regionSize = _exploreRegion(grid, visited, x, y);
        if (regionSize >= _minEnclosedRegionSize &&
            _isEnclosedRegion(grid, x, y, regionSize)) {
          loopCount++;
        }
      }
    }
  }

  return loopCount;
}

/// Explores a connected region of false cells using BFS.
///
/// Returns the size of the explored region.
int _exploreRegion(
  final Artifact grid,
  final Artifact visited,
  final int startX,
  final int startY,
) {
  int rows = grid.rows;
  int cols = grid.cols;
  Queue<List<int>> queue = Queue();
  queue.add([startX, startY]);
  visited.cellSet(startX, startY, true);
  int regionSize = 0;

  final directions = [
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1],
  ];

  while (queue.isNotEmpty) {
    final List<int> current = queue.removeFirst();
    final int x = current[0], y = current[1];
    regionSize++;

    for (final List<int> dir in directions) {
      final int newX = x + dir[0], newY = y + dir[1];

      if (newX >= 0 &&
          newX < cols &&
          newY >= 0 &&
          newY < rows &&
          !grid.cellGet(newX, newY) &&
          !visited.cellGet(newX, newY)) {
        queue.add([newX, newY]);
        visited.cellSet(newX, newY, true);
      }
    }
  }

  return regionSize;
}

/// Determines if a region of false cells is fully enclosed by true cells.
///
/// A region is not enclosed if it reaches the grid edge or is too small
/// relative to the grid area.
bool _isEnclosedRegion(
  final Artifact grid,
  final int startX,
  final int startY,
  final int regionSize,
) {
  final int rows = grid.rows;
  final int cols = grid.cols;
  final Queue<List<int>> queue = Queue();
  final Set<String> visited = {};
  queue.add([startX, startY]);
  visited.add('$startX,$startY');
  bool isEnclosed = true;

  final List<List<int>> directions = [
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1],
  ];

  while (queue.isNotEmpty) {
    final List<int> current = queue.removeFirst();
    final int x = current[0], y = current[1];

    for (final List<int> dir in directions) {
      int newX = x + dir[0], newY = y + dir[1];

      if (newX < 0 || newX >= cols || newY < 0 || newY >= rows) {
        isEnclosed = false;
        continue;
      }

      final String key = '$newX,$newY';
      if (!grid.cellGet(newX, newY) && !visited.contains(key)) {
        queue.add([newX, newY]);
        visited.add(key);
      }
    }
  }

  final int gridArea = rows * cols;
  final double regionPercentage = regionSize / gridArea;
  if (regionPercentage < _minEnclosedRegionAreaRatio) {
    isEnclosed = false;
  }

  return isEnclosed;
}

/// Extension that adds region convenience methods to [Artifact].
extension ArtifactRegionExt on Artifact {
  /// Lazily evaluates and caches the number of enclosed regions.
  int get enclosures => cachedEnclosures ??= countEnclosedRegions(this);

  /// Identifies distinct regions in a dilated binary image.
  List<IntRect> findSubRegions() => _findSubRegions(this);

  /// Finds the connected components (artifacts) in a binary image matrix.
  List<Artifact> findSubArtifacts() => _findSubArtifacts(this);
}

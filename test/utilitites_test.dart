import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:textify/artifact.dart';

void main() async {
  group('floodFill Tests', () {
    test('Basic flood fill on simple matrix', () {
      final Artifact binaryPixels = Artifact.fromAsciiDefinition([
        '.....',
        '.###.',
        '.###.',
        '.###.',
        '.....',
      ]);

      final Artifact visited = Artifact(binaryPixels.cols, binaryPixels.rows);

      final List<Point<int>> points = Artifact.floodFill(
        binaryPixels,
        visited,
        1,
        1,
      );

      expect(points.length, 9);
      expect(points.contains(const Point(1, 1)), true);
      expect(points.contains(const Point(2, 2)), true);
      expect(points.contains(const Point(3, 3)), true);
      expect(points.contains(const Point(0, 0)), false);
    });

    test('Flood fill with disconnected regions', () {
      final Artifact binaryPixels = Artifact.fromAsciiDefinition([
        '..#..',
        '..#..',
        '.....',
        '.##..',
        '.##..',
      ]);

      final Artifact visited = Artifact(binaryPixels.cols, binaryPixels.rows);

      // Fill first region
      final List<Point<int>> region1 = Artifact.floodFill(
        binaryPixels,
        visited,
        2,
        0,
      );
      expect(region1.length, 2);

      // Fill second region
      final List<Point<int>> region2 = Artifact.floodFill(
        binaryPixels,
        visited,
        1,
        3,
      );
      expect(region2.length, 4);
    });

    test('Flood fill with out-of-bounds start point', () {
      final Artifact binaryPixels = Artifact.fromAsciiDefinition([
        '.###.',
        '.###.',
      ]);

      final Artifact visited = Artifact(binaryPixels.cols, binaryPixels.rows);

      final List<Point<int>> points = Artifact.floodFill(
        binaryPixels,
        visited,
        -1,
        0,
      );
      expect(points, isEmpty);
    });

    test('Flood fill starting on empty pixel', () {
      final Artifact binaryPixels = Artifact.fromAsciiDefinition([
        '.###.',
        '.###.',
      ]);

      final Artifact visited = Artifact(binaryPixels.cols, binaryPixels.rows);

      final List<Point<int>> points = Artifact.floodFill(
        binaryPixels,
        visited,
        0,
        0,
      );
      expect(points, isEmpty);
    });
  });

  group('artifact Histograms', () {
    test('Horizontal Histogram', () {
      final artifact = Artifact(3, 3);
      artifact.cellSet(0, 0, true);
      artifact.cellSet(1, 1, true);
      artifact.cellSet(2, 2, true);

      final result = artifact.getHistogramHorizontal();
      expect(result, [1, 1, 1]);
    });

    test('Vertical Histogram', () {
      final artifact = Artifact(3, 3);
      artifact.cellSet(0, 0, true);
      artifact.cellSet(1, 1, true);
      artifact.cellSet(2, 2, true);

      final result = artifact.getHistogramVertical();
      expect(result, [1, 1, 1]);
    });

    test('Horizontal Histogram with empty artifact', () {
      final artifact = Artifact(3, 3);

      final result = artifact.getHistogramHorizontal();
      expect(result, [0, 0, 0]);
    });

    test('Vertical Histogram with empty artifact', () {
      final artifact = Artifact(3, 3);

      final result = artifact.getHistogramVertical();
      expect(result, [0, 0, 0]);
    });

    test('Horizontal Histogram with a row filled', () {
      final artifact = Artifact(3, 3);
      artifact.cellSet(0, 0, true);
      artifact.cellSet(0, 1, true);
      artifact.cellSet(0, 2, true);

      final result = artifact.getHistogramHorizontal();
      expect(result, [3, 0, 0]);
    });

    test('Vertical Histogram with a column filled', () {
      final artifact = Artifact(2, 5);
      artifact.cellSet(0, 0, true);
      artifact.cellSet(0, 1, true);
      artifact.cellSet(0, 2, false);
      artifact.cellSet(0, 3, true);
      artifact.cellSet(0, 4, true);

      final List<int> result = artifact.getHistogramVertical();
      expect(result, [1, 1, 0, 1, 1]);
    });
  });

  group('calculateThreshold Tests', () {
    test('returns -1 for histograms with less than 3 elements', () {
      expect(Artifact.calculateThreshold([1, 2]), -1);
      expect(Artifact.calculateThreshold([]), -1);
    });

    test('finds threshold from valleys in histogram', () {
      // Histogram with clear valleys at positions 1 and 3
      final List<int> histogram = [5, 2, 6, 1, 7];

      // The smallest valley is 1, so that should be the threshold
      expect(Artifact.calculateThreshold(histogram), 1);
    });

    test('handles histogram with multiple valleys', () {
      // Histogram with valleys at positions 1, 3, and 5
      final List<int> histogram = [8, 3, 7, 2, 9, 1, 6];

      // Should average the smallest 20% of valleys (just 1 in this case)
      expect(Artifact.calculateThreshold(histogram), 1);
    });

    test('handles histogram with no valleys', () {
      // Monotonically increasing histogram
      final List<int> histogram = [1, 2, 3, 4, 5];

      // No valleys, should return -1
      expect(Artifact.calculateThreshold(histogram), -1);
    });
  });
}

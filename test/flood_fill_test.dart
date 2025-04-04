import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:textify/artifact.dart';
import 'package:textify/utilities.dart';

void main() {
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

      final List<Point<int>> points = floodFill(binaryPixels, visited, 1, 1);

      expect(points.length, 9);
      expect(points.contains(Point(1, 1)), true);
      expect(points.contains(Point(2, 2)), true);
      expect(points.contains(Point(3, 3)), true);
      expect(points.contains(Point(0, 0)), false);
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
      final List<Point<int>> region1 = floodFill(binaryPixels, visited, 2, 0);
      expect(region1.length, 2);

      // Fill second region
      final List<Point<int>> region2 = floodFill(binaryPixels, visited, 1, 3);
      expect(region2.length, 4);
    });

    test('Flood fill with out-of-bounds start point', () {
      final Artifact binaryPixels = Artifact.fromAsciiDefinition([
        '.###.',
        '.###.',
      ]);

      final Artifact visited = Artifact(binaryPixels.cols, binaryPixels.rows);

      final List<Point<int>> points = floodFill(binaryPixels, visited, -1, 0);
      expect(points, isEmpty);
    });

    test('Flood fill starting on empty pixel', () {
      final Artifact binaryPixels = Artifact.fromAsciiDefinition([
        '.###.',
        '.###.',
      ]);

      final Artifact visited = Artifact(binaryPixels.cols, binaryPixels.rows);

      final List<Point<int>> points = floodFill(binaryPixels, visited, 0, 0);
      expect(points, isEmpty);
    });
  });
}

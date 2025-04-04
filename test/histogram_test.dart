import 'package:flutter_test/flutter_test.dart';

import 'package:textify/artifact.dart';

void main() async {
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
      expect(calculateHistogramValleyThreshold([1, 2]), -1);
      expect(calculateHistogramValleyThreshold([]), -1);
    });

    test('finds threshold from valleys in histogram', () {
      // Histogram with clear valleys at positions 1 and 3
      final List<int> histogram = [5, 2, 6, 1, 7];

      // The smallest valley is 1, so that should be the threshold
      expect(calculateHistogramValleyThreshold(histogram), 1);
    });

    test('handles histogram with multiple valleys', () {
      // Histogram with valleys at positions 1, 3, and 5
      final List<int> histogram = [8, 3, 7, 2, 9, 1, 6];

      // Should average the smallest 20% of valleys (just 1 in this case)
      expect(calculateHistogramValleyThreshold(histogram), 1);
    });

    test('handles histogram with no valleys', () {
      // Monotonically increasing histogram
      final List<int> histogram = [1, 2, 3, 4, 5];

      // No valleys, should return -1
      expect(calculateHistogramValleyThreshold(histogram), -1);
    });
  });
}

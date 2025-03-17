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
}

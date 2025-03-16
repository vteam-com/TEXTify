import 'package:flutter_test/flutter_test.dart';

import 'package:textify/matrix.dart';

void main() async {
  group('Matrix Histograms', () {
    test('Horizontal Histogram', () {
      final matrix = Matrix(3, 3);
      matrix.cellSet(0, 0, true);
      matrix.cellSet(1, 1, true);
      matrix.cellSet(2, 2, true);

      final result = matrix.getHistogramHorizontal();
      expect(result, [1, 1, 1]);
    });

    test('Vertical Histogram', () {
      final matrix = Matrix(3, 3);
      matrix.cellSet(0, 0, true);
      matrix.cellSet(1, 1, true);
      matrix.cellSet(2, 2, true);

      final result = matrix.getHistogramVertical();
      expect(result, [1, 1, 1]);
    });

    test('Horizontal Histogram with empty matrix', () {
      final matrix = Matrix(3, 3);

      final result = matrix.getHistogramHorizontal();
      expect(result, [0, 0, 0]);
    });

    test('Vertical Histogram with empty matrix', () {
      final matrix = Matrix(3, 3);

      final result = matrix.getHistogramVertical();
      expect(result, [0, 0, 0]);
    });

    test('Horizontal Histogram with a row filled', () {
      final matrix = Matrix(3, 3);
      matrix.cellSet(0, 0, true);
      matrix.cellSet(0, 1, true);
      matrix.cellSet(0, 2, true);

      final result = matrix.getHistogramHorizontal();
      expect(result, [3, 0, 0]);
    });

    test('Vertical Histogram with a column filled', () {
      final matrix = Matrix(2, 5);
      matrix.cellSet(0, 0, true);
      matrix.cellSet(0, 1, true);
      matrix.cellSet(0, 2, false);
      matrix.cellSet(0, 3, true);
      matrix.cellSet(0, 4, true);

      final List<int> result = matrix.getHistogramVertical();
      expect(result, [1, 1, 0, 1, 1]);
    });
  });
}

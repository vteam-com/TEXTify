import 'package:flutter_test/flutter_test.dart';

import 'package:textify/matrix.dart';

void main() {
  group('splitRegionIntoRows Tests', () {
    test('Split with no empty rows', () {
      List<String> input = [
        '.####.',
        '##..##',
        '.......',
        '.......',
        '######',
        '##..##',
        '######',
      ];

      final Matrix matrix = Matrix.fromAsciiDefinition(input);
      final List<Matrix> rows = splitRegionIntoRows(matrix);

      expect(rows[0], isNotEmpty);
      expect(rows[1], isEmpty);
      expect(rows[2], isNotEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:textify/artifact.dart';
import 'package:textify/int_rect.dart';

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

      final Artifact matrix = Artifact.fromAsciiDefinition(input);
      final List<Artifact> rows = splitRegionIntoRows(matrix);

      expect(rows[0], isNotEmpty);
      expect(rows[1], isEmpty);
      expect(rows[2], isNotEmpty);
    });
  });

  test('Find regions in binary matrix', () {
    List<String> input = [
      '..#....',
      '.###...',
      '..#....',
      '.......',
      '...##..',
      '...##..',
    ];

    final Artifact matrix = Artifact.fromAsciiDefinition(input);
    final List<IntRect> regions = findRegions(dilatedMatrixImage: matrix);

    expect(regions.length, 2);

    // First region (the larger pattern at the top)
    expect(regions[0].left, 1);
    expect(regions[0].top, 0);
    expect(regions[0].width, 3);
    expect(regions[0].height, 3);

    // Second region (the square at the bottom)
    expect(regions[1].left, 3);
    expect(regions[1].top, 4);
    expect(regions[1].width, 2);
    expect(regions[1].height, 2);
  });
}

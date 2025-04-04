import 'package:flutter_test/flutter_test.dart';
import 'package:textify/bands.dart';
import 'package:textify/utilities.dart';

void main() {
  group('Artifact Merging Tests', () {
    test('Merging 2 overlapping artifacts', () {
      final artifact1 = Artifact.fromAsciiDefinition(
        [
          '#..',
          '..#',
          '#..',
        ],
      );

      final artifact2 = Artifact.fromAsciiDefinition(
        [
          '..#',
          '#..',
          '..#',
        ],
      );

      artifact1.mergeArtifact(artifact2);

      expect(artifact1.toText(), '#.#\n#.#\n#.#');
    });

    test('Real test', () {
      final artifact1 = Artifact.fromAsciiDefinition(
        [
          '..............',
          '..............',
          '..............',
          '..............',
          '..............',
          '..............',
          '#############.',
          '..###.......#.',
          '..###.........',
          '..###.........',
          '..###.........',
          '..###......#..',
          '..###......#..',
          '..###......#..',
          '..##########..',
          '..###.....##..',
          '..###......#..',
          '..###.........',
          '..###.........',
          '..###.........',
          '..###.........',
          '..###........#',
          '..###.......##',
          '##############',
        ],
      );
      artifact1.locationFound = IntOffset(10, 0);

      final artifact2 = Artifact.fromAsciiDefinition(
        [
          '..',
          '..',
          '..',
          '..',
          '..',
          '..',
          '..',
          '..',
          '#.',
          '#.',
          '..',
          '..',
          '..',
          '..',
          '..',
          '..',
          '..',
          '..',
          '..',
          '.#',
          '..',
          '..',
          '..',
          '..',
        ],
      );
      artifact2.locationFound = IntOffset(23, 0);

      artifact1.mergeArtifact(artifact2);
    });

    test('Merging overlapping artifacts in a Band', () {
      final artifact1 = Artifact.fromAsciiDefinition(
        [
          '#..',
          '..#',
          '#..',
        ],
      );

      final artifact2 = Artifact.fromAsciiDefinition(
        [
          '..#',
          '#..',
          '..#',
        ],
      );

      final artifact3 = Artifact.fromAsciiDefinition(
        [
          '..',
          '.#',
        ],
      );

      Band band = Band();
      band.addArtifact(artifact1);
      band.addArtifact(artifact2);
      band.addArtifact(artifact3);

      expect(band.artifacts.length, 3);

      band.mergeArtifactsBasedOnVerticalAlignment();
      expect(band.artifacts.length, 1);
      // print(band.artifacts.first.toText());
    });

    test('Not Merging two non-overlapping artifacts', () {
      final artifact1 = Artifact.fromAsciiDefinition(
        [
          '#..',
          '..#',
          '#..',
        ],
      );

      final artifact2 = Artifact.fromAsciiDefinition(
        [
          '..#',
          '#..',
          '..#',
        ],
      );
      artifact2.locationFound = IntOffset(30, 30);

      Band band = Band();
      band.addArtifact(artifact1);
      band.addArtifact(artifact2);

      expect(band.artifacts.length, 2);

      band.mergeArtifactsBasedOnVerticalAlignment();
      expect(band.artifacts.length, 2);
    });
  });

  group('Artifact Padding Tests', () {
    test('Padding top and bottom with zeros', () {
      final artifact = Artifact.fromAsciiDefinition(
        [
          '#.#',
          '.#.',
          '#.#',
        ],
      );

      artifact.padTopBottom(paddingTop: 0, paddingBottom: 0);

      expect(artifact.gridToStrings(), [
        '#.#',
        '.#.',
        '#.#',
      ]);
    });

    test('Padding with zero top padding', () {
      final artifact = Artifact.fromAsciiDefinition(
        [
          '#.#',
          '.#.',
        ],
      );

      artifact.padTopBottom(paddingTop: 0, paddingBottom: 2);

      expect(artifact.gridToStrings(), [
        '#.#',
        '.#.',
        '...',
        '...',
      ]);
    });

    test('Padding with zero bottom padding', () {
      final artifact = Artifact.fromAsciiDefinition(
        [
          '#.#',
          '.#.',
        ],
      );

      artifact.padTopBottom(paddingTop: 2, paddingBottom: 0);

      expect(artifact.gridToStrings(), [
        '...',
        '...',
        '#.#',
        '.#.',
      ]);
    });

    test('Padding single row artifact', () {
      final artifact = Artifact.fromAsciiDefinition(
        [
          '#.#',
        ],
      );

      artifact.padTopBottom(paddingTop: 1, paddingBottom: 1);

      expect(artifact.gridToStrings(), [
        '...',
        '#.#',
        '...',
      ]);
    });

    test('Padding with large values', () {
      final artifact = Artifact.fromAsciiDefinition(
        [
          '#',
        ],
      );

      artifact.padTopBottom(paddingTop: 100, paddingBottom: 100);

      expect(artifact.rows, 201);
      expect(artifact.toText().split('\n').length, 201);
    });
  });

  group('Artifact Trim Tests', () {
    test('Trim empty artifact', () {
      final artifact = Artifact(5, 5);
      final trimmed = artifact.trim();
      expect(trimmed.rows, 0);
      expect(trimmed.cols, 0);
    });

    test('Trim artifact with content only in corners', () {
      final artifact = Artifact.fromAsciiDefinition([
        '#..#',
        '....',
        '....',
        '#..#',
      ]);

      final trimmed = artifact.trim();
      expect(trimmed.rows, 4);
      expect(trimmed.cols, 4);
      expect(trimmed.toText(), '#..#\n....\n....\n#..#');
    });

    test('Trim artifact with single cell content', () {
      final artifact = Artifact.fromAsciiDefinition([
        '.....',
        '..#..',
        '.....',
      ]);
      final trimmed = artifact.trim();
      expect(trimmed.rows, 1);
      expect(trimmed.cols, 1);
      expect(trimmed.toText(), '#');
    });

    test('Trim artifact with content in middle rows only', () {
      final artifact = Artifact.fromAsciiDefinition([
        '......',
        '......',
        '..##..',
        '..##..',
        '......',
        '......',
      ]);
      final trimmed = artifact.trim();
      expect(trimmed.rows, 2);
      expect(trimmed.cols, 2);
      expect(trimmed.toText(), '##\n##');
    });

    test('Trim artifact with content in single column', () {
      final artifact = Artifact.fromAsciiDefinition([
        '..#..',
        '..#..',
        '..#..',
        '..#..',
      ]);
      final trimmed = artifact.trim();
      expect(trimmed.rows, 4);
      expect(trimmed.cols, 1);
      expect(trimmed.toText(), '#\n#\n#\n#');
    });

    test('Trim artifact with single row content', () {
      final artifact = Artifact.fromAsciiDefinition([
        '......',
        '......',
        '..####',
        '......',
        '......',
      ]);
      final trimmed = artifact.trim();
      expect(trimmed.rows, 1);
      expect(trimmed.cols, 4);
      expect(trimmed.toText(), '####');
    });
  });

  group('Artifact Normalization Tests', () {
    test('createNormalizeMatrix resizes artifact correctly', () {
      // Create a test artifact
      final artifact = Artifact.fromAsciiDefinition([
        '##..',
        '.##.',
        '..##',
      ]);

      // Test resizing to larger dimensions
      final resizedLarger = artifact.createNormalizeMatrix(6, 5);
      expect(resizedLarger.cols, 6);
      expect(resizedLarger.rows, 5);
      expect(
        resizedLarger.gridToStrings(),
        [
          '......',
          '.##...',
          '..##..',
          '...##.',
          '......',
        ],
      );

      // Test resizing to smaller dimensions
      final resizedSmaller = artifact.createNormalizeMatrix(2, 2);
      expect(resizedSmaller.cols, 2);
      expect(resizedSmaller.rows, 2);
      expect(
        resizedSmaller.gridToStrings(),
        [
          '##',
          '##',
        ],
      );

      // Test with punctuation
      final punctuation = Artifact.fromAsciiDefinition([
        '.#.',
        '###',
        '.#.',
      ]);

      punctuation.characterMatched = '.';

      final resizedPunctuation = punctuation.createNormalizeMatrix(5, 5);
      expect(resizedPunctuation.cols, 5);
      expect(resizedPunctuation.rows, 5);
      expect(
        resizedPunctuation.gridToStrings(),
        [
          '.....',
          '..#..',
          '.###.',
          '..#..',
          '.....',
        ],
      );
    });
  });

  group('calculateThreshold Tests', () {
    test('Empty histogram returns -1', () {
      final List<int> histogram = [1, 2];
      final int threshold = calculateHistogramValleyThreshold(histogram);
      expect(threshold, -1);
    });

    test('Histogram with no valleys uses average height', () {
      final List<int> histogram = [1, 2, 3, 4, 5];
      final int threshold = calculateHistogramValleyThreshold(histogram);
      // Average is 3, threshold should be 3 * 0.5 = 1.5 -> 1
      expect(threshold, -1);
    });

    test('Histogram with valleys adjusts threshold', () {
      final List<int> histogram = [5, 2, 7, 1, 6];
      final int threshold = calculateHistogramValleyThreshold(histogram);
      // Valley is 1, threshold should be 1 * 0.8 = 0.8 -> 0
      expect(threshold, 1);
    });

    test('Histogram with multiple valleys uses minimum', () {
      final List<int> histogram = [5, 2, 7, 3, 9, 1, 8];
      final int threshold = calculateHistogramValleyThreshold(histogram);
      // Valleys are 2, 3, 1; minimum is 1
      expect(threshold, 1);
    });
  });
}

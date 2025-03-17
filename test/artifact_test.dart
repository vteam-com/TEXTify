import 'package:flutter_test/flutter_test.dart';
import 'package:textify/bands.dart';
import 'package:textify/int_rect.dart';

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

      band.mergeConnectedArtifactsInPlace();
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

      band.mergeConnectedArtifactsInPlace();
      expect(band.artifacts.length, 2);
    });
  });
}

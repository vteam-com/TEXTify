import 'package:flutter_test/flutter_test.dart';
import 'package:textify/artifact.dart';
import 'package:textify/bands.dart';

void main() {
  group('mergeBandsHorizontally', () {
    test('handles single band', () {
      final band = Band();
      final bands = Bands([band]);
      bands.mergeBandsHorizontally();
      expect(bands.length, 1);
    });

    test('merges multiple empty bands in sequence', () {
      final band1 = Band();
      final band2 = Band();
      final band3 = Band();
      final bands = Bands([band1, band2, band3]);
      bands.mergeBandsHorizontally();

      // Nothing sould have change since there's no data in the bands to take action on
      expect(bands.length, 3);

      // now test that we can clean up
      bands.removeEmptyBands();
      expect(bands.length, 0);
    });

    test('merges adjacent bands with vertical alignment', () {
      // BAND 1 LEFT
      final Band band1 = Band();
      final Artifact artifact1 = Artifact();
      artifact1.matrix.setBothLocation(Offset(10, 10));
      artifact1.matrix.setGrid([
        [true, false, true],
        [true, false, true],
      ]);
      band1.addArtifact(artifact1);

      // BAND 2 RIGHT
      final Band band2 = Band();
      final Artifact artifact2 = Artifact();
      artifact2.matrix.setBothLocation(Offset(14, 10));
      artifact2.matrix.setGrid([
        [true, false, true],
        [true, false, true],
      ]);
      band2.addArtifact(artifact2);

      // ALL BANDS
      final Bands bands = Bands([band1, band2]);
      bands.mergeBandsHorizontally();

      expect(bands.length, 1);
      expect(
        bands.list.first.artifacts.length,
        3, // adding two bands will also add a space artifact between them
      );
    });

    test('does not merge bands with large horizontal gap', () {
      final Band band1 = Band();
      final Artifact artifact1 = Artifact();
      artifact1.matrix.setBothLocation(Offset(10, 10));
      band1.addArtifact(artifact1);

      final Band band2 = Band();
      final Artifact artifact2 = Artifact();
      artifact2.matrix.setBothLocation(Offset(500, 10));
      band2.addArtifact(artifact2);

      final Bands bands = Bands([band1, band2]);
      bands.mergeBandsHorizontally();

      expect(bands.length, 2);
    });
  });

  group('sorting of band', () {
    test('sorts bands by vertical position first', () {
      final band1 = Band();
      final artifact1 = Artifact();
      artifact1.matrix.setBothLocation(Offset(10, 20));
      band1.addArtifact(artifact1);

      final band2 = Band();
      final artifact2 = Artifact();
      artifact2.matrix.setBothLocation(Offset(5, 10));
      band2.addArtifact(artifact2);

      final bands = Bands([band1, band2]);
      bands.sortTopLeftToBottomRight();

      expect(bands.list[0], band2);
      expect(bands.list[1], band1);
    });

    test('sorts bands horizontally when at same vertical position', () {
      final band1 = Band();
      final artifact1 = Artifact();
      artifact1.matrix.setBothLocation(Offset(20, 10));
      band1.addArtifact(artifact1);

      final band2 = Band();
      final artifact2 = Artifact();
      artifact2.matrix.setBothLocation(Offset(10, 10));
      band2.addArtifact(artifact2);

      final bands = Bands([band1, band2]);
      bands.sortTopLeftToBottomRight();

      expect(bands.list[0], band2);
      expect(bands.list[1], band1);
    });

    test('maintains order for bands at exact same position', () {
      final band1 = Band();
      final artifact1 = Artifact();
      artifact1.matrix.setBothLocation(Offset(10, 10));
      band1.addArtifact(artifact1);

      final band2 = Band();
      final artifact2 = Artifact();
      artifact2.matrix.setBothLocation(Offset(10, 10));
      band2.addArtifact(artifact2);

      final bands = Bands([band1, band2]);
      bands.sortTopLeftToBottomRight();

      expect(bands.list[0], band1);
      expect(bands.list[1], band2);
    });

    test('handles empty bands list', () {
      final bands = Bands([]);
      bands.sortTopLeftToBottomRight();
      expect(bands.length, 0);
    });
  });
}

import 'dart:ui';

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
      final Band band1 = Band();
      final Artifact artifact1 = Artifact();
      artifact1.matrix.setBothRects(Rect.fromLTWH(10, 10, 30, 30));
      band1.addArtifact(artifact1);

      final Band band2 = Band();
      final Artifact artifact2 = Artifact();
      artifact2.matrix.setBothRects(Rect.fromLTWH(50, 10, 30, 30));
      band2.addArtifact(artifact2);

      final Bands bands = Bands([band1, band2]);
      bands.mergeBandsHorizontally();

      expect(bands.length, 1);
      expect(bands.list[0].artifacts.length, 2);
    });

    test('does not merge bands with large horizontal gap', () {
      final Band band1 = Band();
      final Artifact artifact1 = Artifact();
      artifact1.matrix.setBothRects(Rect.fromLTWH(10, 10, 30, 30));
      band1.addArtifact(artifact1);

      final Band band2 = Band();
      final Artifact artifact2 = Artifact();
      artifact2.matrix.setBothRects(Rect.fromLTWH(500, 10, 30, 30));
      band2.addArtifact(artifact2);

      final Bands bands = Bands([band1, band2]);
      bands.mergeBandsHorizontally();

      expect(bands.length, 2);
    });
  });
}

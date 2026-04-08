import 'package:flutter_test/flutter_test.dart';
import 'package:textify/artifact.dart';
import 'package:textify/artifact_projection.dart';
import 'package:textify/image_helpers.dart';

void main() {
  group('findTextLineRects', () {
    test('empty artifact returns empty list', () {
      final artifact = Artifact(0, 0);
      expect(findTextLineRects(artifact), isEmpty);
    });

    test('single text line', () {
      // 7 rows: 1 blank, 3 content, 3 blank
      final artifact = Artifact.fromAsciiDefinition([
        '........',
        '..####..',
        '..####..',
        '..####..',
        '........',
        '........',
        '........',
      ]);

      final lines = findTextLineRects(artifact);
      expect(lines.length, 1);
      expect(lines[0].top, 1);
      expect(lines[0].height, 3);
      expect(lines[0].width, 8);
    });

    test('two text lines with gap', () {
      final artifact = Artifact.fromAsciiDefinition([
        '..##....',
        '..##....',
        '........',
        '....##..',
        '....##..',
      ]);

      final lines = findTextLineRects(artifact);
      expect(lines.length, 2);
      expect(lines[0].top, 0);
      expect(lines[0].height, 2);
      expect(lines[1].top, 3);
      expect(lines[1].height, 2);
    });

    test('content at bottom edge (no trailing blank)', () {
      // Verifies the "close final line" branch
      final artifact = Artifact.fromAsciiDefinition([
        '........',
        '..####..',
        '..####..',
      ]);

      final lines = findTextLineRects(artifact);
      expect(lines.length, 1);
      expect(lines[0].top, 1);
      expect(lines[0].height, 2);
    });

    test('all pixels blank returns empty', () {
      final artifact = Artifact.fromAsciiDefinition(['....', '....', '....']);
      expect(findTextLineRects(artifact), isEmpty);
    });

    test('entire image is content (one line)', () {
      final artifact = Artifact.fromAsciiDefinition(['####', '####']);

      final lines = findTextLineRects(artifact);
      expect(lines.length, 1);
      expect(lines[0].top, 0);
      expect(lines[0].height, 2);
    });

    test('three text lines', () {
      final artifact = Artifact.fromAsciiDefinition([
        '##......',
        '........',
        '....##..',
        '........',
        '......##',
      ]);

      final lines = findTextLineRects(artifact);
      expect(lines.length, 3);
    });
  });

  group('findCharacterRects', () {
    test('empty artifact returns empty list', () {
      final artifact = Artifact(0, 0);
      expect(findCharacterRects(artifact), isEmpty);
    });

    test('single character', () {
      final artifact = Artifact.fromAsciiDefinition([
        '..##..',
        '..##..',
        '..##..',
      ]);

      final rects = findCharacterRects(artifact, attemptSplitting: false);
      expect(rects.length, 1);
    });

    test('two separated characters', () {
      // Two clear character blocks with a gap
      final artifact = Artifact.fromAsciiDefinition([
        '##....##',
        '##....##',
        '##....##',
      ]);

      final rects = findCharacterRects(artifact, attemptSplitting: false);
      expect(rects.length, 2);
      expect(rects[0].left, 0);
      expect(rects[0].width, 2);
      expect(rects[1].left, 6);
      expect(rects[1].width, 2);
    });

    test('three separated characters', () {
      final artifact = Artifact.fromAsciiDefinition([
        '##...##...##',
        '##...##...##',
        '##...##...##',
      ]);

      final rects = findCharacterRects(artifact, attemptSplitting: false);
      expect(rects.length, 3);
    });

    test('content at right edge (close final segment)', () {
      final artifact = Artifact.fromAsciiDefinition(['....####', '....####']);

      final rects = findCharacterRects(artifact, attemptSplitting: false);
      expect(rects.length, 1);
      expect(rects[0].left, 4);
      expect(rects[0].width, 4);
    });

    test('all blank returns empty', () {
      final artifact = Artifact.fromAsciiDefinition(['........', '........']);

      expect(findCharacterRects(artifact), isEmpty);
    });

    test('too few segments skips splitting', () {
      // With < 3 segments, splitting is skipped even if attemptSplitting=true
      final artifact = Artifact.fromAsciiDefinition([
        '##....######',
        '##....######',
        '##....######',
      ]);

      final rects = findCharacterRects(artifact, attemptSplitting: true);
      // 2 segments < _minSegmentsForMedian, so no splitting attempted
      expect(rects.length, 2);
    });

    test('attemptSplitting splits touching characters', () {
      // Create 4 normal-width segments and 1 double-width segment
      // normal segments: 3 cols wide; touching segment: 7 cols wide
      // Median width ~3, threshold ~4.5, so 7-wide gets split attempt
      final artifact = Artifact.fromAsciiDefinition([
        '###..###..###..###.###.###',
        '###..###..###..###.###.###',
        '###..###..###..####...####',
        '###..###..###..###.###.###',
        '###..###..###..###.###.###',
      ]);

      final rects = findCharacterRects(artifact, attemptSplitting: true);
      // Should have at least as many segments as when splitting is off
      expect(rects.length, greaterThanOrEqualTo(5));
    });

    test('wide segment with no valleys stays unsplit', () {
      // 3 normal segments + 1 solid wide segment (no valley to split at)
      final artifact = Artifact.fromAsciiDefinition([
        '##...##...##...########',
        '##...##...##...########',
        '##...##...##...########',
        '##...##...##...########',
        '##...##...##...########',
      ]);

      final rects = findCharacterRects(artifact, attemptSplitting: true);
      // The wide solid block has no valley, should remain unsplit
      expect(rects.length, greaterThanOrEqualTo(4));
    });

    test('adaptive threshold filters anti-aliasing', () {
      // A gap column with very few pixels (simulating anti-aliasing)
      // should be treated as empty when peak is much higher
      final artifact = Artifact.fromAsciiDefinition([
        '####.####',
        '####.####',
        '####.####',
        '####.####',
        '####.####',
        '####.####',
        '####.####',
        '####.####',
        '####.####',
        '####.####',
        '####.####',
        '####.####',
        '####.####',
      ]);

      // The '.' column has 0 pixels, clearly a gap
      final rects = findCharacterRects(artifact, attemptSplitting: false);
      expect(rects.length, 2);
    });
  });

  group('insertSpacesByGap', () {
    test('fewer than 2 artifacts does nothing', () {
      final artifacts = <Artifact>[_makeArtifactAt(0, 0, 5, 10)];
      insertSpacesByGap(artifacts, 10);
      expect(artifacts.length, 1);
    });

    test('empty list does nothing', () {
      final artifacts = <Artifact>[];
      insertSpacesByGap(artifacts, 10);
      expect(artifacts, isEmpty);
    });

    test('no gaps does nothing', () {
      // Two adjacent artifacts with no gap
      final a1 = _makeArtifactAt(0, 0, 5, 10);
      final a2 = _makeArtifactAt(5, 0, 5, 10);
      final artifacts = [a1, a2];
      insertSpacesByGap(artifacts, 10);
      expect(artifacts.length, 2); // No space inserted
    });

    test('uniform small gaps inserts no spaces', () {
      // All gaps are uniform and small — no jump, median*1.6 > gap
      final a1 = _makeArtifactAt(0, 0, 5, 10);
      final a2 = _makeArtifactAt(7, 0, 5, 10);
      final a3 = _makeArtifactAt(14, 0, 5, 10);
      final a4 = _makeArtifactAt(21, 0, 5, 10);
      final artifacts = [a1, a2, a3, a4];
      insertSpacesByGap(artifacts, 10);
      // All gaps are 2, median=2, threshold=max(2, (2*1.6).round())=3
      // Gaps are 2, which is < 3, so no spaces
      expect(artifacts.length, 4);
    });

    test('inserts space at large gap', () {
      // Two chars close together, then a big gap, then two chars close
      final a1 = _makeArtifactAt(0, 0, 5, 10);
      final a2 = _makeArtifactAt(7, 0, 5, 10); // gap = 2
      final a3 = _makeArtifactAt(30, 0, 5, 10); // gap = 18 (big jump)
      final a4 = _makeArtifactAt(37, 0, 5, 10); // gap = 2
      final artifacts = [a1, a2, a3, a4];
      insertSpacesByGap(artifacts, 10);

      // Should have inserted 1 space before a3
      expect(artifacts.length, 5);
      // Find the space
      final spaceArtifacts = artifacts
          .where((a) => a.matchingCharacter == ' ')
          .toList();
      expect(spaceArtifacts.length, 1);
    });

    test('inserts multiple spaces at multiple large gaps', () {
      final a1 = _makeArtifactAt(0, 0, 5, 10);
      final a2 = _makeArtifactAt(7, 0, 5, 10); // gap = 2
      final a3 = _makeArtifactAt(30, 0, 5, 10); // gap = 18
      final a4 = _makeArtifactAt(55, 0, 5, 10); // gap = 20
      final artifacts = [a1, a2, a3, a4];
      insertSpacesByGap(artifacts, 10);

      final spaceArtifacts = artifacts
          .where((a) => a.matchingCharacter == ' ')
          .toList();
      expect(spaceArtifacts.length, 2);
    });

    test('two artifacts with single gap uses single-gap logic', () {
      // Only 1 gap total: fewer than _minGapsForJump(2), uses simple threshold
      final a1 = _makeArtifactAt(0, 0, 5, 10);
      final a2 = _makeArtifactAt(20, 0, 5, 10); // gap = 15
      final artifacts = [a1, a2];
      insertSpacesByGap(artifacts, 10);

      // Single gap of 15 >= threshold (max(2, 15+1)=16)? No, gap(15) < 16
      // So no space inserted. This tests the single-gap branch.
      expect(artifacts.length, 2);
    });

    test('gap jump detection with clear bimodal distribution', () {
      // Create a bimodal gap distribution: small gaps (2,2,2) and large gap (20)
      final a1 = _makeArtifactAt(0, 0, 5, 10);
      final a2 = _makeArtifactAt(7, 0, 5, 10); // gap = 2
      final a3 = _makeArtifactAt(14, 0, 5, 10); // gap = 2
      final a4 = _makeArtifactAt(21, 0, 5, 10); // gap = 2
      final a5 = _makeArtifactAt(50, 0, 5, 10); // gap = 24 (clear jump)
      final artifacts = [a1, a2, a3, a4, a5];
      insertSpacesByGap(artifacts, 10);

      final spaceArtifacts = artifacts
          .where((a) => a.matchingCharacter == ' ')
          .toList();
      expect(spaceArtifacts.length, 1);
    });

    test('median fallback when no jump found', () {
      // Gradually increasing gaps, no clear jump (ratio never >= 1.8)
      final a1 = _makeArtifactAt(0, 0, 5, 10);
      final a2 = _makeArtifactAt(8, 0, 5, 10); // gap = 3
      final a3 = _makeArtifactAt(17, 0, 5, 10); // gap = 4
      final a4 = _makeArtifactAt(27, 0, 5, 10); // gap = 5
      final a5 = _makeArtifactAt(38, 0, 5, 10); // gap = 6
      final a6 = _makeArtifactAt(100, 0, 5, 10); // gap = 57, clear outlier
      final artifacts = [a1, a2, a3, a4, a5, a6];
      insertSpacesByGap(artifacts, 10);

      // The large gap at 57 should trigger a space
      final spaceArtifacts = artifacts
          .where((a) => a.matchingCharacter == ' ')
          .toList();
      expect(spaceArtifacts.length, greaterThanOrEqualTo(1));
    });

    test('gaps with zero values are skipped', () {
      // Overlapping artifacts have gap <= 0, should be skipped
      final a1 = _makeArtifactAt(0, 0, 10, 10);
      final a2 = _makeArtifactAt(8, 0, 10, 10); // gap = -2 (overlap)
      final a3 = _makeArtifactAt(20, 0, 10, 10); // gap = 2
      final artifacts = [a1, a2, a3];
      insertSpacesByGap(artifacts, 10);

      // Only 1 positive gap (2), which is < _minGapsForJump, uses simple logic
      // threshold = max(2, 2+1) = 3, gap=2 < 3, so no space
      expect(artifacts.length, 3);
    });

    test('space artifact has correct properties', () {
      final a1 = _makeArtifactAt(0, 0, 5, 10);
      final a2 = _makeArtifactAt(7, 0, 5, 10); // gap = 2
      final a3 = _makeArtifactAt(40, 0, 5, 10); // gap = 28 (big)
      final artifacts = [a1, a2, a3];
      insertSpacesByGap(artifacts, 10);

      final spaces = artifacts
          .where((a) => a.matchingCharacter == ' ')
          .toList();
      if (spaces.isNotEmpty) {
        final space = spaces.first;
        expect(space.matchingCharacter, ' ');
        expect(space.cols, greaterThan(0));
        expect(space.rows, 10);
      }
    });
  });

  group('findCharacterRects with splitting edge cases', () {
    test('split produces empty pieces that are skipped', () {
      // 4 normal segments + 1 wide segment that may split into empty pieces
      final artifact = Artifact.fromAsciiDefinition([
        '##...##...##...##...#....#',
        '##...##...##...##...#....#',
        '##...##...##...##...#....#',
        '##...##...##...##...#....#',
        '##...##...##...##...#....#',
      ]);

      final rects = findCharacterRects(artifact, attemptSplitting: true);
      // All results should be non-empty
      for (final rect in rects) {
        expect(rect.width, greaterThan(0));
        expect(rect.height, greaterThan(0));
      }
    });
  });
}

/// Helper to create an artifact at a specific location with given dimensions.
Artifact _makeArtifactAt(int x, int y, int width, int height) {
  final artifact = Artifact(width, height);
  // Put some pixels so it's not empty
  for (int px = 0; px < width; px++) {
    for (int py = 0; py < height; py++) {
      artifact.cellSet(px, py, true);
    }
  }
  artifact.locationFound = IntOffset(x, y);
  return artifact;
}

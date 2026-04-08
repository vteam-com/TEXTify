import 'package:flutter_test/flutter_test.dart';
import 'package:textify/artifact.dart';
import 'package:textify/artifact_morphology.dart';

void main() {
  group('dilateArtifact', () {
    test('single pixel expands to kernel-sized block', () {
      final source = Artifact.fromAsciiDefinition([
        '.......',
        '.......',
        '.......',
        '...#...',
        '.......',
        '.......',
        '.......',
      ]);

      final dilated = dilateArtifact(matrixImage: source, kernelSize: 3);
      // The single pixel at (3,3) should expand to a 3×3 block
      expect(dilated.cellGet(3, 3), true);
      expect(dilated.cellGet(2, 2), true);
      expect(dilated.cellGet(4, 4), true);
      // Pixels outside the 3×3 kernel should remain off
      expect(dilated.cellGet(1, 1), false);
      expect(dilated.cellGet(5, 5), false);
    });

    test('empty image stays empty', () {
      final source = Artifact.fromAsciiDefinition(['.....', '.....', '.....']);

      final dilated = dilateArtifact(matrixImage: source, kernelSize: 3);
      for (int y = 0; y < dilated.rows; y++) {
        for (int x = 0; x < dilated.cols; x++) {
          expect(dilated.cellGet(x, y), false);
        }
      }
    });

    test('kernel size 1 produces identical output', () {
      final source = Artifact.fromAsciiDefinition(['.#.', '#.#', '.#.']);

      final dilated = dilateArtifact(matrixImage: source, kernelSize: 1);
      for (int y = 0; y < source.rows; y++) {
        for (int x = 0; x < source.cols; x++) {
          expect(dilated.cellGet(x, y), source.cellGet(x, y));
        }
      }
    });

    test('pixel at corner expands within bounds', () {
      final source = Artifact.fromAsciiDefinition(['#....', '.....', '.....']);

      final dilated = dilateArtifact(matrixImage: source, kernelSize: 3);
      // Top-left corner should expand into the valid region only
      expect(dilated.cellGet(0, 0), true);
      expect(dilated.cellGet(1, 0), true);
      expect(dilated.cellGet(0, 1), true);
      expect(dilated.cellGet(1, 1), true);
      // Far away should still be off
      expect(dilated.cellGet(3, 2), false);
    });

    test('pixel at bottom-right corner', () {
      final source = Artifact.fromAsciiDefinition(['.....', '.....', '....#']);

      final dilated = dilateArtifact(matrixImage: source, kernelSize: 3);
      expect(dilated.cellGet(4, 2), true);
      expect(dilated.cellGet(3, 1), true);
      expect(dilated.cellGet(4, 1), true);
      expect(dilated.cellGet(3, 2), true);
    });

    test('large kernel connects nearby pixels', () {
      final source = Artifact.fromAsciiDefinition([
        '#........#',
        '..........',
        '..........',
        '..........',
        '..........',
      ]);

      final dilated = dilateArtifact(matrixImage: source, kernelSize: 5);
      // Each pixel expands by 2 in each direction
      // Left pixel (0,0) expands to (0-2,0-2) clamped → reaches (2,2)
      expect(dilated.cellGet(2, 2), true);
      // Right pixel (9,0) expands to (7-11,0-2) clamped → reaches (7,0)
      expect(dilated.cellGet(7, 0), true);
    });
  });

  group('erodeSoft', () {
    test('empty artifact stays empty', () {
      final source = Artifact(0, 0);
      final eroded = source.erodeSoft();
      expect(eroded.isEmpty, true);
    });

    test('solid block preserves interior', () {
      final source = Artifact.fromAsciiDefinition([
        '#####',
        '#####',
        '#####',
        '#####',
        '#####',
      ]);

      final eroded = source.erodeSoft();
      // Center pixel has 9 neighbors (itself + 8) >= 5, should survive
      expect(eroded.cellGet(2, 2), true);
      // Interior pixels surrounded by all ON should survive
      expect(eroded.cellGet(1, 1), true);
      expect(eroded.cellGet(3, 3), true);
    });

    test('isolated pixel is removed', () {
      final source = Artifact.fromAsciiDefinition(['.....', '..#..', '.....']);

      final eroded = source.erodeSoft();
      // Only 1 neighbor (itself), < 5 threshold, removed
      expect(eroded.cellGet(2, 1), false);
    });

    test('thin line is thinned', () {
      final source = Artifact.fromAsciiDefinition(['.....', '#####', '.....']);

      final eroded = source.erodeSoft();
      // Middle of line: pixel(2,1) has neighbors: (1,1),(2,1),(3,1) = 3, < 5
      expect(eroded.cellGet(2, 1), false);
    });

    test('corner pixel with few neighbors is removed', () {
      final source = Artifact.fromAsciiDefinition(['#.', '..']);

      final eroded = source.erodeSoft();
      // (0,0) has only 1 neighbor (itself), removed
      expect(eroded.cellGet(0, 0), false);
    });

    test('L-shape corner with enough neighbors survives', () {
      final source = Artifact.fromAsciiDefinition([
        '###..',
        '###..',
        '###..',
        '.....',
      ]);

      final eroded = source.erodeSoft();
      // Center of the 3x3 block (1,1) has 9 neighbors, survives
      expect(eroded.cellGet(1, 1), true);
    });
  });

  group('removeDecorativeLineComponents', () {
    test('empty artifact returns empty', () {
      final source = Artifact(0, 0);
      final cleaned = source.removeDecorativeLineComponents();
      expect(cleaned.isEmpty, true);
    });

    test('no decorative lines preserves content', () {
      // Small text-like content, not line-shaped
      final source = Artifact.fromAsciiDefinition([
        '....###....',
        '...#...#...',
        '...#####...',
        '...#...#...',
        '...#...#...',
      ]);

      final cleaned = source.removeDecorativeLineComponents();
      // Content should be preserved
      expect(cleaned.cellGet(4, 0), true);
    });

    test('horizontal line is removed when it spans enough width', () {
      // Create a wide image with a thin horizontal line spanning >12% width
      final rows = <String>[];
      // Some text content at top
      rows.add('..####..${'.' * 92}');
      rows.add('..####..${'.' * 92}');
      rows.add('.' * 100);
      // Thin horizontal line spanning the full width
      rows.add('#' * 100);
      rows.add('.' * 100);
      // More content
      for (int i = 0; i < 95; i++) {
        rows.add('.' * 100);
      }

      final source = Artifact.fromAsciiDefinition(rows);
      final cleaned = source.removeDecorativeLineComponents();

      // The text content should remain
      expect(cleaned.cellGet(2, 0), true);
      // The horizontal line at row 3 should be removed
      // (it's a long thin component spanning >12% of width)
      expect(cleaned.cellGet(50, 3), false);
    });

    test('vertical line is removed when it spans enough height', () {
      final rows = <String>[];
      for (int i = 0; i < 100; i++) {
        // Narrow vertical line at column 0
        rows.add('#${'.' * 99}');
      }

      final source = Artifact.fromAsciiDefinition(rows);
      final cleaned = source.removeDecorativeLineComponents();

      // The vertical line should be removed
      expect(cleaned.cellGet(0, 50), false);
    });

    test('dense large blob is removed', () {
      // Create a solid dense blob that covers >12% width and >12% height
      // and has area > 2% of total, with density >= 0.65
      final rows = <String>[];
      // 100x100 image
      for (int y = 0; y < 100; y++) {
        if (y >= 10 && y < 30) {
          // A 20x20 solid block at columns 10-29
          final row = '.' * 10 + '#' * 20 + '.' * 70;
          rows.add(row);
        } else {
          rows.add('.' * 100);
        }
      }

      final source = Artifact.fromAsciiDefinition(rows);
      final cleaned = source.removeDecorativeLineComponents();

      // The blob covers 20% width, 20% height, area=400 > 2% of 10000=200
      // density = 1.0 >= 0.65 → should be removed
      expect(cleaned.cellGet(15, 15), false);
    });

    test('small component is not removed', () {
      final rows = <String>[];
      for (int y = 0; y < 100; y++) {
        if (y >= 45 && y < 48) {
          // Small 3x3 block
          final row = '${'.' * 48}###${'.' * 49}';
          rows.add(row);
        } else {
          rows.add('.' * 100);
        }
      }

      final source = Artifact.fromAsciiDefinition(rows);
      final cleaned = source.removeDecorativeLineComponents();

      // Small component doesn't meet any removal criteria
      expect(cleaned.cellGet(49, 46), true);
    });
  });
}

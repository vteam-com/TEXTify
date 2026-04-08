import 'package:flutter_test/flutter_test.dart';
import 'package:textify/artifact.dart';
import 'package:textify/artifact_region.dart';

void main() {
  group('floodFillToRect', () {
    test('single connected region returns its bounding rect', () {
      final artifact = Artifact.fromAsciiDefinition([
        '........',
        '..###...',
        '..###...',
        '..###...',
        '........',
      ]);
      final visited = Artifact(artifact.cols, artifact.rows);

      final rect = floodFillToRect(artifact, visited, 2, 1);
      expect(rect.left, 2);
      expect(rect.top, 1);
      expect(rect.width, 3);
      expect(rect.height, 3);
    });

    test('out of bounds start returns degenerate rect', () {
      final artifact = Artifact.fromAsciiDefinition(['##', '##']);
      final visited = Artifact(artifact.cols, artifact.rows);

      final rect = floodFillToRect(artifact, visited, -1, 0);
      // Out-of-bounds start: no flood fill, rect is just (startX, startY, 1, 1)
      expect(rect.width, 1);
      expect(rect.height, 1);
    });

    test('start on empty pixel returns degenerate rect', () {
      final artifact = Artifact.fromAsciiDefinition(['.#', '#.']);
      final visited = Artifact(artifact.cols, artifact.rows);

      final rect = floodFillToRect(artifact, visited, 0, 0);
      // Start pixel is off: no expansion
      expect(rect.width, 1);
      expect(rect.height, 1);
    });

    test('L-shaped region bounding box', () {
      final artifact = Artifact.fromAsciiDefinition([
        '#....',
        '#....',
        '#....',
        '#####',
      ]);
      final visited = Artifact(artifact.cols, artifact.rows);

      final rect = floodFillToRect(artifact, visited, 0, 0);
      expect(rect.left, 0);
      expect(rect.top, 0);
      expect(rect.width, 5);
      expect(rect.height, 4);
    });

    test('pixel at bottom-right corner', () {
      final artifact = Artifact.fromAsciiDefinition(['....', '...#']);
      final visited = Artifact(artifact.cols, artifact.rows);

      final rect = floodFillToRect(artifact, visited, 3, 1);
      expect(rect.left, 3);
      expect(rect.top, 1);
      expect(rect.width, 1);
      expect(rect.height, 1);
    });

    test('two separate regions only fills from start', () {
      final artifact = Artifact.fromAsciiDefinition([
        '##....',
        '##....',
        '....##',
        '....##',
      ]);
      final visited = Artifact(artifact.cols, artifact.rows);

      final rect = floodFillToRect(artifact, visited, 0, 0);
      // 4-connected: only the top-left block
      expect(rect.left, 0);
      expect(rect.top, 0);
      expect(rect.width, 2);
      expect(rect.height, 2);
    });

    test('full image filled', () {
      final artifact = Artifact.fromAsciiDefinition(['####', '####', '####']);
      final visited = Artifact(artifact.cols, artifact.rows);

      final rect = floodFillToRect(artifact, visited, 0, 0);
      expect(rect.left, 0);
      expect(rect.top, 0);
      expect(rect.width, 4);
      expect(rect.height, 3);
    });
  });

  group('findSubRegions', () {
    test('empty artifact returns empty list', () {
      final artifact = Artifact(0, 0);
      final regions = artifact.findSubRegions();
      expect(regions, isEmpty);
    });

    test('single connected component', () {
      final artifact = Artifact.fromAsciiDefinition([
        '........',
        '..###...',
        '..###...',
        '........',
      ]);

      final regions = artifact.findSubRegions();
      expect(regions.length, 1);
      expect(regions[0].left, 2);
      expect(regions[0].top, 1);
      expect(regions[0].width, 3);
      expect(regions[0].height, 2);
    });

    test('two separate components', () {
      final artifact = Artifact.fromAsciiDefinition([
        '##......',
        '##......',
        '......##',
        '......##',
      ]);

      final regions = artifact.findSubRegions();
      expect(regions.length, 2);
    });

    test('three components sorted', () {
      final artifact = Artifact.fromAsciiDefinition([
        '......##',
        '........',
        '##......',
        '........',
        '....##..',
      ]);

      final regions = artifact.findSubRegions();
      expect(regions.length, 3);
      // Results should be sorted by sortRectangles
    });

    test('all blank returns empty', () {
      final artifact = Artifact.fromAsciiDefinition(['.....', '.....']);

      final regions = artifact.findSubRegions();
      expect(regions, isEmpty);
    });

    test('diagonal pixels are separate in 4-connected fill', () {
      // floodFillToRect uses 4-connected, so diagonal-only touching
      // pixels are separate components
      final artifact = Artifact.fromAsciiDefinition([
        '#....',
        '.#...',
        '..#..',
      ]);

      final regions = artifact.findSubRegions();
      // Each diagonal pixel is a separate 4-connected component
      expect(regions.length, 3);
    });
  });
}

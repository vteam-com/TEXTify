import 'package:textify/band.dart';

/// Exports
export 'package:textify/band.dart';

///
class Bands {
  ///
  Bands([List<Band> bands = const <Band>[]]) {
    list.addAll(bands);
  }

  /// List of text bands identified in the image.
  final List<Band> list = [];

  ///
  void clear() => list.clear();

  ///
  int get length => list.length;

  ///
  int get totalArtifacts =>
      this.list.fold(0, (sum, band) => sum + band.artifacts.length);

  ///
  void add(final Band band) {
    list.add(band);
  }

  ///
  int indexOf(final Band band) {
    return list.indexOf(band);
  }

  /// Groups artifacts into horizontal bands based on their vertical positions.
  ///
  /// This method organizes artifacts into bands, which are horizontal groupings
  /// of artifacts that are vertically close to each other. The process involves:
  /// 1. Sorting artifacts by their top y-position.
  /// 2. Iterating through sorted artifacts and assigning them to existing bands
  ///    or creating new bands as necessary.
  ///
  /// The method uses a vertical tolerance to determine if an artifact belongs
  /// to an existing band.
  void mergeBandsHorizontally() {
    bool mergedAny = true;
    while (mergedAny) {
      mergedAny = false;

      for (int i = 0; i < list.length - 1; i++) {
        Band leftBand = list[i];
        Band rightBand = list[i + 1];

        //
        // Step 1 - Calculate vertical center overlap
        //
        double leftCenter = leftBand.rectangleAdjusted.center.dy;
        double rightCenter = rightBand.rectangleAdjusted.center.dy;
        double centerDiff = (leftCenter - rightCenter).abs();
        double avgHeight = (leftBand.rectangleAdjusted.height +
                rightBand.rectangleAdjusted.height) /
            2;

        // Check if bands are horizontally adjacent and vertically aligned
        if (centerDiff < avgHeight * 0.3) {
          //
          // Step 2 - Calculate horizontal distance between bands
          //
          double horizontalDistance = rightBand.rectangleAdjusted.left -
              leftBand.rectangleAdjusted.right;

          // Centers are within 30% of average height
          if (horizontalDistance > 0) {
            // Bands don't overlap
            if (horizontalDistance <= (leftBand.averageWidth * 1.9)) {
              // Merge right band artifacts into left band
              for (var artifact in rightBand.artifacts) {
                leftBand.addArtifact(artifact);
              }

              // Remove the right band
              list.removeAt(i + 1);
              mergedAny = true;
              break;
            }
          }
        }
      }
    }
  }

  /// Removes bands that have no artifacts from the given list
  void removeEmptyBands() {
    list.removeWhere((band) {
      band.removeEmptyArtifacts();
      return band.artifacts.isEmpty;
    });
  }

  ///
  void trimBands() {
    this.list.forEach((band) {
      band.trim();
    });
  }
}

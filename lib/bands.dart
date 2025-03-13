import 'package:textify/band.dart';

/// Exports
export 'package:textify/band.dart';

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
void mergeBandsHorizontally(final List<Band> bands) {
  bool mergedAny = true;
  while (mergedAny) {
    mergedAny = false;

    for (int i = 0; i < bands.length - 1; i++) {
      Band leftBand = bands[i];
      Band rightBand = bands[i + 1];

      //
      // Step 1 - Calculate vertical center overlap
      //
      double leftCenter = leftBand.rectangle.center.dy;
      double rightCenter = rightBand.rectangle.center.dy;
      double centerDiff = (leftCenter - rightCenter).abs();
      double avgHeight =
          (leftBand.rectangle.height + rightBand.rectangle.height) / 2;

      // Check if bands are horizontally adjacent and vertically aligned
      if (centerDiff < avgHeight * 0.3) {
        //
        // Step 2 - Calculate horizontal distance between bands
        //
        double horizontalDistance =
            rightBand.rectangle.left - leftBand.rectangle.right;

        // Centers are within 30% of average height
        if (horizontalDistance > 0) {
          // Bands don't overlap
          if (horizontalDistance <= (leftBand.averageWidth * 1.9)) {
            // Merge right band artifacts into left band
            for (var artifact in rightBand.artifacts) {
              leftBand.addArtifact(artifact);
            }

            // Remove the right band
            bands.removeAt(i + 1);
            mergedAny = true;
            break;
          }
        }
      }
    }
  }
}

/// Removes bands that have no artifacts from the given list
void removeEmptyBands(final List<Band> bands) {
  bands.removeWhere((band) {
    band.removeEmptyArtifacts();
    return band.artifacts.isEmpty;
  });
}

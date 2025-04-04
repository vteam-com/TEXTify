import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:textify/band.dart';
import 'package:textify/int_rect.dart';

// Exports
export 'package:textify/int_rect.dart';

/// Converts a color image to a binary (black and white) image.
///
/// This preprocessing step simplifies the image for text recognition by
/// converting it to a binary format where text is represented as black pixels
/// on a white background.
///
/// [image] is the source color image to convert.
/// Returns a ```Future<ui.Image>``` containing the binary version of the input image.
Future<Image> imageToBlackOnWhite(
  final Image inputImage, {
  // Adjust contrast level (0 = normal, 100 = high contrast)
  double contrast = 0,
}) async {
  final int width = inputImage.width;
  final int height = inputImage.height;
  final Uint8List pixels = await imageToUint8List(inputImage);

  // Calculate contrast factor
  final double factor = (259 * (contrast + 255)) / (255 * (259 - contrast));

  // Create a new Uint8List for the output image
  Uint8List outputPixels = Uint8List(pixels.length);
  for (int i = 0; i < pixels.length; i += 4) {
    final int r = pixels[i];
    final int g = pixels[i + 1];
    final int b = pixels[i + 2];
    // ignore: unused_local_variable
    final int a = pixels[i + 3];

    // Calculate brightness using a weighted average
    int gray = (0.299 * r + 0.587 * g + 0.114 * b).toInt();

    // Apply contrast adjustment
    gray = (factor * (gray - 128) + 128).clamp(0, 255).toInt();

    outputPixels[i] = gray;
    outputPixels[i + 1] = gray;
    outputPixels[i + 2] = gray;
    outputPixels[i + 3] = 255; // Drop alpha
  }

  // Compute threshold dynamically
  int threshold = computeAdaptiveThreshold(outputPixels, width, height);

  // Apply binary threshold
  Uint8List bwPixels = Uint8List(outputPixels.length);
  for (int i = 0; i < outputPixels.length; i += 4) {
    final int gray = outputPixels[i];
    final int newColor = (gray > threshold) ? 255 : 0;

    bwPixels[i] = newColor;
    bwPixels[i + 1] = newColor;
    bwPixels[i + 2] = newColor;
    bwPixels[i + 3] = 255; // Drop alpha
  }

  // Convert Uint8List back to Image
  return await createImageFromPixels(bwPixels, width, height);
}

/// Computes an adaptive threshold for converting a grayscale image to black and white.
///
/// This function takes a list of grayscale pixel values and computes a threshold value
/// that can be used to convert the image to a black and white representation. The threshold
/// is computed by taking the average of all the pixel values and subtracting 100 from it.
/// This helps to create a sharper separation between the foreground and background.
///
/// Parameters:
/// - [pixels]: A list of grayscale pixel values.
/// - [width]: The width of the image in pixels.
/// - [height]: The height of the image in pixels.
///
/// Returns:
/// The computed adaptive threshold value.
/// Compute adaptive threshold dynamically
// Compute adaptive threshold dynamically
int computeAdaptiveThreshold(Uint8List pixels, int width, int height) {
  int sum = 0, count = 0;
  for (int i = 0; i < pixels.length; i += 4) {
    sum += pixels[i];
    count++;
  }

  // Adjust threshold for sharper separation
  return (sum ~/ count) - 90;
}

/// Converts a [Image] to a [Uint8List] representation.
///
/// This function takes a [Image] and converts it to a [Uint8List] containing
/// the raw RGBA data of the image.
///
/// Parameters:
/// - [image]: The source image to be converted. Can be null.
///
/// Returns:
/// A [Future] that resolves to a [Uint8List] containing the raw RGBA data of the image.
/// If the input [image] is null or conversion fails, returns an empty [Uint8List].
Future<Uint8List> imageToUint8List(final Image image) async {
  final ByteData? data =
      await image.toByteData(format: ImageByteFormat.rawRgba);
  return data?.buffer.asUint8List() ?? Uint8List(0);
}

/// Performs a highly optimized flood fill algorithm on a binary image matrix.
///
/// This implementation uses direct array access and efficient data structures
/// to significantly improve performance over the traditional approach.
///
/// Parameters:
///   [binaryPixels]: A Matrix representing the binary image where true values
///                   indicate filled pixels.
///   [visited]: A Matrix of the same size as [binaryPixels] to keep track of
///              visited pixels.
///   [startX]: The starting X coordinate for the flood fill.
///   [startY]: The starting Y coordinate for the flood fill.
///
/// Returns:
///   A List of Point objects representing all connected points found during
///   the flood fill process.
List<Point<int>> floodFill(
  final Artifact binaryPixels,
  final Artifact visited,
  final int startX,
  final int startY,
) {
  final int width = binaryPixels.cols;
  final int height = binaryPixels.rows;

  // Early bounds check
  if (startX < 0 || startX >= width || startY < 0 || startY >= height) {
    return const [];
  }

  // Early check for valid starting pixel
  if (!binaryPixels.cellGet(startX, startY)) {
    return const [];
  }

  // Direct access to the underlying arrays
  final Uint8List pixelData = binaryPixels.matrix;
  final Uint8List visitedData = visited.matrix;

  // Pre-allocate with estimated capacity to reduce reallocations
  final List<Point<int>> connectedPoints = <Point<int>>[];
  final Queue<int> queue = Queue<int>();

  // Calculate initial index
  final int startIndex = startY * width + startX;

  // Mark start point as visited and add to queue
  visitedData[startIndex] = 1;
  queue.add(startIndex);

  // Direction offsets for adjacent pixels
  const List<int> rowOffsets = [0, 0, -1, 1]; // Row adjustments
  const List<int> colOffsets = [-1, 1, 0, 0]; // Column adjustments

  while (queue.isNotEmpty) {
    final int currentIndex = queue.removeFirst();
    final int x = currentIndex % width;
    final int y = currentIndex ~/ width;

    // Add current point to result
    connectedPoints.add(Point(x, y));

    // Check all four directions
    for (int i = 0; i < 4; i++) {
      final int nx = x + colOffsets[i];
      final int ny = y + rowOffsets[i];

      // Skip out-of-bounds
      if (nx < 0 || nx >= width || ny < 0 || ny >= height) {
        continue;
      }

      final int neighborIndex = ny * width + nx;

      // Check if neighbor is valid and not visited
      if (pixelData[neighborIndex] == 1 && visitedData[neighborIndex] == 0) {
        visitedData[neighborIndex] = 1;
        queue.add(neighborIndex);
      }
    }
  }

  return connectedPoints;
}

/// Performs a flood fill algorithm and directly calculates the bounding rectangle
/// without storing all individual points.
///
/// Parameters:
///   [binaryPixels]: A Matrix representing the binary image.
///   [visited]: A Matrix to keep track of visited pixels.
///   [startX]: The starting X coordinate for the flood fill.
///   [startY]: The starting Y coordinate for the flood fill.
///
/// Returns:
///   An IntRect representing the bounding rectangle of the connected region.
IntRect floodFillToRect(
  final Artifact binaryPixels,
  final Artifact visited,
  final int startX,
  final int startY,
) {
  final int width = binaryPixels.cols;
  final int height = binaryPixels.rows;

  // Initialize bounds to starting point
  int minX = startX;
  int minY = startY;
  int maxX = startX;
  int maxY = startY;

  // Early bounds check
  if (startX >= 0 && startX < width && startY >= 0 && startY < height) {
    // Early check for valid starting pixel
    if (binaryPixels.cellGet(startX, startY)) {
      // Direct access to the underlying arrays
      final Uint8List pixelData = binaryPixels.matrix;
      final Uint8List visitedData = visited.matrix;

      final Queue<int> queue = Queue<int>();

      // Calculate initial index
      final int startIndex = startY * width + startX;

      // Mark start point as visited and add to queue
      visitedData[startIndex] = 1;
      queue.add(startIndex);

      // Direction offsets for adjacent pixels
      const List<int> rowOffsets = [0, 0, -1, 1]; // Row adjustments
      const List<int> colOffsets = [-1, 1, 0, 0]; // Column adjustments

      while (queue.isNotEmpty) {
        final int currentIndex = queue.removeFirst();
        final int x = currentIndex % width;
        final int y = currentIndex ~/ width;

        // Update bounds
        minX = min(minX, x);
        minY = min(minY, y);
        maxX = max(maxX, x);
        maxY = max(maxY, y);

        // Check all four directions
        for (int i = 0; i < 4; i++) {
          final int nx = x + colOffsets[i];
          final int ny = y + rowOffsets[i];

          // Skip out-of-bounds
          if (nx < 0 || nx >= width || ny < 0 || ny >= height) {
            continue;
          }

          final int neighborIndex = ny * width + nx;

          // Check if neighbor is valid and not visited
          if (pixelData[neighborIndex] == 1 &&
              visitedData[neighborIndex] == 0) {
            visitedData[neighborIndex] = 1;
            queue.add(neighborIndex);
          }
        }
      }
    }
  }

  // Calculate width and height
  final int regionWidth = maxX - minX + 1;
  final int regionHeight = maxY - minY + 1;

  return IntRect.fromLTWH(
    minX,
    minY,
    regionWidth,
    regionHeight,
  );
}

/// Computes the appropriate kernel size for dilation based on image dimensions.
///
/// [cols] is the width of the image in pixels.
/// [rows] is the height of the image in pixels.
/// [factor] is a scaling factor that determines how the kernel size relates to image dimensions.
/// Returns an integer representing the computed kernel size.
int computeKernelSize(int width, int height, double scaleFactor) {
  return (scaleFactor * width).round().clamp(1, width);
}

/// Applies dilation morphological operation to a binary image.
///
/// Dilation expands the white regions in a binary image, which helps connect
/// nearby text elements and fill small gaps in characters.
///
/// [matrixImage] is the source binary image to dilate.
/// [kernelSize] determines the size of the dilation kernel.
/// Returns a new Artifact containing the dilated image.
Artifact dilateArtifact({
  required final Artifact matrixImage,
  required int kernelSize,
}) {
  final Artifact result = Artifact(matrixImage.cols, matrixImage.rows);
  final int halfKernel = kernelSize ~/ 2;
  final int width = matrixImage.cols;
  final int height = matrixImage.rows;

  // Pre-compute row boundaries for each y position to avoid repeated calculations
  final List<int> minKYs = List<int>.filled(height, 0);
  final List<int> maxKYs = List<int>.filled(height, 0);
  for (int y = 0; y < height; y++) {
    minKYs[y] = max(0, y - halfKernel);
    maxKYs[y] = min(height - 1, y + halfKernel);
  }

  // Pre-compute column boundaries for each x position
  final List<int> minKXs = List<int>.filled(width, 0);
  final List<int> maxKXs = List<int>.filled(width, 0);
  for (int x = 0; x < width; x++) {
    minKXs[x] = max(0, x - halfKernel);
    maxKXs[x] = min(width - 1, x + halfKernel);
  }

  // Process the image
  // For large images, process in chunks
  // First pass: find all pixels that are set in the original image
  // and mark their kernel areas in the result
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      if (matrixImage.cellGet(x, y)) {
        // This pixel is set, so dilate it by setting all pixels in its kernel area
        for (int ky = minKYs[y]; ky <= maxKYs[y]; ky++) {
          for (int kx = minKXs[x]; kx <= maxKXs[x]; kx++) {
            result.cellSet(kx, ky, true);
          }
        }
      }
    }
  }

  return result;
}

/// Creates a new [Image] from a [Uint8List] of pixel data.
///
/// This function takes a [Uint8List] containing the pixel data, the [width],
/// and the [height] of the image, and creates a new [Image] from it.
///
/// Parameters:
/// - [pixels]: The [Uint8List] containing the pixel data.
/// - [width]: The width of the image.
/// - [height]: The height of the image.
///
/// Returns:
/// A [Future] that resolves to a [Image] created from the pixel data.
Future<Image> createImageFromPixels(
  final Uint8List pixels,
  final int width,
  final int height,
) async {
  // Create a new Image from the modified pixels
  final ImmutableBuffer buffer = await ImmutableBuffer.fromUint8List(pixels);

  // Create a new Image from the modified pixels
  final ImageDescriptor descriptor = ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: PixelFormat.rgba8888,
  );
  final Codec codec = await descriptor.instantiateCodec();
  final FrameInfo frameInfo = await codec.getNextFrame();

  return frameInfo.image;
}

/// Applies an offset to the location of a list of matrices.
///
/// This function translates the locationFound property of each matrix in the list
/// by the specified x and y offsets.
///
/// Parameters:
/// - [matrices]: The list of Artifact objects to offset.
/// - [x]: The horizontal offset to apply.
/// - [y]: The vertical offset to apply.
void offsetArtifacts(final List<Artifact> matrices, final int x, final int y) {
  matrices.forEach(
    (matrix) => matrix.locationFound = matrix.locationFound.translate(x, y),
  );
}

/// Creates a [Artifact] from a [Image].
///
/// This factory constructor takes a [Image] object and transforms it into a [Artifact]
/// representation. The process involves two main steps:
/// 1. Converting the image to a Uint8List using [imageToUint8List].
/// 2. Creating a Matrix from the Uint8List using [Matrix.fromUint8List].
///
/// [image] The Image object to be converted. This should be a valid,
/// non-null image object.
///
/// Returns a [Future<Artifact>] representing the image data. The returned Matrix
/// will have the same width as the input image, and its height will be
/// determined by the length of the Uint8List and the width.
///
/// Throws an exception if [imageToUint8List] fails to convert the image or if
/// [Matrix.fromUint8List] encounters an error during matrix creation.
///
/// Note: This constructor is asynchronous due to the [imageToUint8List] operation.
/// Ensure to await its result when calling.
Future<Artifact> artifactFromImage(final Image image) async {
  final Uint8List uint8List = await imageToUint8List(image);
  return Artifact.fromUint8List(uint8List, image.width);
}

/// Copies the contents of a source Matrix into a target Matrix, with an optional offset.
///
/// This method copies the values from the source Matrix into the target Matrix,
/// starting at the specified offset coordinates. If the source Matrix extends
/// beyond the bounds of the target Matrix, only the portion that fits within
/// the target Matrix will be copied.
///
/// Parameters:
/// - `source`: The Matrix to copy from.
/// - `target`: The Matrix to copy into.
/// - `offsetX`: The horizontal offset to apply when copying the source into the target.
/// - `offsetY`: The vertical offset to apply when copying the source into the target.
void copyArtifactGrid(
  final Artifact source,
  final Artifact target,
  final int offsetX,
  final int offsetY,
) {
  for (int y = 0; y < source.rows; y++) {
    for (int x = 0; x < source.cols; x++) {
      if (y + offsetY < target.rows && x + offsetX < target.cols) {
        if (source.cellGet(x, y)) {
          target.cellSet(x + offsetX, y + offsetY, true);
        }
      }
    }
  }
}

/// Returns a list of column indices where the artifact should be split
///
/// This method analyzes the horizontal histogram of the artifact to identify
/// valleys (columns with fewer pixels) that are good candidates for splitting.
///
/// If all columns have identical values (no valleys or peaks), returns an empty list
/// indicating no splitting is needed.
///
/// Returns:
/// A list of column indices where splits should occur.
List<int> artifactValleysOffsets(final Artifact artifact) {
  final List<int> peaksAndValleys = artifact.getHistogramHorizontal();

  // Check if all columns have identical values
  final bool allIdentical =
      peaksAndValleys.every((value) => value == peaksAndValleys[0]);
  if (allIdentical) {
    // no valleys
    return [];
  }

  final List<int> offsets = [];

  // Calculate a more appropriate threshold for large artifacts
  final int threshold = calculateThreshold(peaksAndValleys);

  if (threshold >= 0) {
    // Find columns where the pixel count is below the threshold
    final List<List<int>> gaps = [];
    List<int> currentGap = [];

    // Identify gaps (consecutive columns below threshold)
    for (int i = 0; i < peaksAndValleys.length; i++) {
      if (peaksAndValleys[i] <= threshold) {
        currentGap.add(i);
      } else if (currentGap.isNotEmpty) {
        gaps.add(List.from(currentGap));
        currentGap = [];
      }
    }

    // Add the last gap if it exists
    if (currentGap.isNotEmpty) {
      gaps.add(currentGap);
    }

    // Filter out gaps that are at the edges of the artifact
    // These are likely serifs or other character features, not actual gaps between characters
    gaps.removeWhere((gap) {
      // Remove gaps that start at column 0 (left edge)
      if (gap.first == 0) {
        return true;
      }

      // Remove gaps that end at the last column (right edge)
      if (gap.last == peaksAndValleys.length - 1) {
        return true;
      }

      // Keep all other gaps
      return false;
    });

    // Sort the gaps by position (ascending) to maintain left-to-right order
    gaps.sort((a, b) => a[0].compareTo(b[0]));

    // For each gap, use the middle of the gap as the split column

    for (final List<int> gap in gaps) {
      if (gap.isNotEmpty) {
        // Calculate the middle point of the gap
        final int splitPoint = gap.first + (gap.length ~/ 2);
        offsets.add(splitPoint);
      }
    }
  }

  return offsets;
}

/// Splits the given matrix into multiple row matrices based on the provided row offsets.
///
/// Each row offset in [offsets] marks the start of a new split.
/// The function returns a list of [Artifact] objects, where each matrix represents
/// a horizontal slice of the original [artifactToSplit] matrix while maintaining its relative position.
///
/// Example:
/// ```dart
/// Matrix input = Matrix(5, 5);
/// List<int> rowOffsets = [0, 2, 4]; // Splits at row indices 0, 2, and 4
/// List<Matrix> rowMatrices = Matrix.splitAsRows(input, rowOffsets);
/// ```
///
/// - [artifactToSplit]: The original matrix to split.
/// - [offsets]: A list of row indices where splits should occur.
/// - Returns: A list of matrices representing the split rows while preserving `locationFound`.
List<Artifact> splitArtifactByColumns(
  final Artifact artifactToSplit,
  List<int> offsets,
) {
  List<Artifact> result = [];

  // Handle the first segment (from 0 to first offset)
  if (offsets.isNotEmpty && offsets[0] > 0) {
    Artifact firstSegment = Artifact(offsets[0], artifactToSplit.rows);

    // Copy the relevant columns
    for (int x = 0; x < offsets[0]; x++) {
      for (int y = 0; y < artifactToSplit.rows; y++) {
        firstSegment.cellSet(x, y, artifactToSplit.cellGet(x, y));
      }
    }

    // Set location properties
    firstSegment.locationFound = IntOffset(
      artifactToSplit.locationFound.x,
      artifactToSplit.locationFound.y,
    );

    firstSegment.locationAdjusted = IntOffset(
      artifactToSplit.locationAdjusted.x,
      artifactToSplit.locationAdjusted.y,
    );

    firstSegment.wasPartOfSplit = true;
    result.add(firstSegment);
  }

  // Handle middle segments and last segment
  for (int i = 0; i < offsets.length; i++) {
    int columnStart = offsets[i];
    int columnEnd =
        (i < offsets.length - 1) ? offsets[i + 1] : artifactToSplit.cols;

    // Skip if this segment has no width
    if (columnEnd <= columnStart) {
      continue;
    }

    // Create segment
    Artifact segment = Artifact(columnEnd - columnStart, artifactToSplit.rows);

    // Copy the relevant columns
    for (int x = columnStart; x < columnEnd; x++) {
      for (int y = 0; y < artifactToSplit.rows; y++) {
        segment.cellSet(x - columnStart, y, artifactToSplit.cellGet(x, y));
      }
    }

    // Set location properties
    segment.locationFound = IntOffset(
      artifactToSplit.locationFound.x + columnStart,
      artifactToSplit.locationFound.y,
    );

    segment.locationAdjusted = IntOffset(
      artifactToSplit.locationAdjusted.x + columnStart,
      artifactToSplit.locationAdjusted.y,
    );

    segment.wasPartOfSplit = true;
    result.add(segment);
  }

  return result;
}

/// Calculates an appropriate threshold for identifying valleys in a histogram
///
/// This function finds the smallest valleys (local minima) in the histogram,
/// which represent the gaps between characters.
///
/// Parameters:
/// - [histogram]: A list of integer values representing the histogram.
///
/// Returns:
/// An integer threshold value, or -1 if a valid threshold couldn't be determined.
int calculateThreshold(List<int> histogram) {
  // need at least 3 elements to have a valley
  if (histogram.length >= 3) {
    // Find all valleys (local minima)
    List<int> valleys = [];

    // Handle single-point valleys
    for (int i = 1; i < histogram.length - 1; i++) {
      if (histogram[i] < histogram[i - 1] && histogram[i] < histogram[i + 1]) {
        valleys.add(histogram[i]);
      }
    }

    // Handle flat valleys (consecutive identical values that are lower than neighbors)
    for (int i = 1; i < histogram.length - 2; i++) {
      // Check if we have a sequence of identical values
      if (histogram[i] == histogram[i + 1]) {
        // Find the end of this flat region
        int j = i + 1;
        while (j < histogram.length - 1 && histogram[j] == histogram[i]) {
          j++;
        }

        // Check if this flat region is a valley (lower than both neighbors)
        if (i > 0 &&
            j < histogram.length &&
            histogram[i] < histogram[i - 1] &&
            histogram[i] < histogram[j]) {
          valleys.add(histogram[i]);
        }

        // Skip to the end of this flat region
        i = j - 1;
      }
    }

    // If we found valleys, use the smallest one as threshold
    if (valleys.isNotEmpty) {
      int smallestValley = valleys.reduce(min);
      return (smallestValley * 1.2)
          .toInt(); // Slightly higher than smallest valley
    }
  }
  // If no valleys found, return -1 to indicate that splitting is not possible
  return -1;
}

/// Calculates the normalized Hamming distance between two matrices.
///
/// The Hamming distance is the number of positions at which the corresponding
/// elements in two matrices are different. This method computes a normalized
/// similarity score based on the Hamming distance.
///
/// Parameters:
/// - [inputGrid]: The first Matrix to compare.
/// - [templateGrid]: The second Matrix to compare against.
///
/// Returns:
/// A double value between 0 and 1, where:
/// - 1.0 indicates perfect similarity (no differences)
/// - 0.0 indicates maximum dissimilarity (all elements are different)
///
/// Note: This method assumes that both matrices have the same dimensions.
/// If the matrices have different sizes, the behavior is undefined and may
/// result in errors or incorrect results.
double hammingDistancePercentageOfTwoArtifacts(
  final Artifact inputGrid,
  final Artifact templateGrid,
) {
  if (inputGrid.cols != templateGrid.cols) {
    return 0;
  }
  if (inputGrid.rows != templateGrid.rows) {
    return 0;
  }

  int matchingPixels = 0;
  int totalPixels = 0;

  for (int y = 0; y < inputGrid.rows; y++) {
    for (int x = 0; x < inputGrid.cols; x++) {
      if (inputGrid.cellGet(x, y) || templateGrid.cellGet(x, y)) {
        totalPixels++;
        if (inputGrid.cellGet(x, y) == templateGrid.cellGet(x, y)) {
          matchingPixels++;
        }
      }
    }
  }

  if (totalPixels == 0) {
    return 0.0;
  } // If no true pixels, consider it a perfect match

  return matchingPixels / totalPixels;
}

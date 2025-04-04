import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:textify/artifact.dart';
import 'package:textify/int_rect.dart';

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
Future<Uint8List> imageToUint8List(final Image? image) async {
  if (image == null) {
    return Uint8List(0);
  }
  final ByteData? data =
      await image.toByteData(format: ImageByteFormat.rawRgba);
  return data?.buffer.asUint8List() ?? Uint8List(0);
}

/// Finds the regions in a binary image matrix.
///
/// This method performs a flood fill algorithm to identify connected regions
/// in a binary image matrix. It creates a dilated copy of the binary image
/// to merge nearby pixels, and then scans through each pixel to find
/// connected regions. The method returns a list of [Rect] objects
/// representing the bounding boxes of the identified regions.
///
/// Parameters:
///   [binaryImages]: The binary image matrix to analyze.
///
/// Returns:
///   A list of [Rect] objects representing the bounding boxes of the
///   identified regions.
List<Artifact> findMatrices({required Artifact dilatedMatrixImage}) {
  // Clear existing regions
  List<Artifact> regions = [];

  // Create a matrix to track visited pixels
  final Artifact visited =
      Artifact(dilatedMatrixImage.cols, dilatedMatrixImage.rows);

  // Scan through each pixel
  for (int y = 0; y < dilatedMatrixImage.rows; y++) {
    for (int x = 0; x < dilatedMatrixImage.cols; x++) {
      // If pixel is on and not visited, flood fill from this point
      if (!visited.cellGet(x, y) && dilatedMatrixImage.cellGet(x, y)) {
        // Get connected points using flood fill
        final List<Point<int>> connectedPoints = floodFill(
          dilatedMatrixImage,
          visited,
          x,
          y,
        );

        if (connectedPoints.isEmpty) {
          continue;
        }
        regions.add(matrixFromPoints(connectedPoints));
      }
    }
  }

  Artifact.sortMatrices(regions);
  return regions;
}

/// Identifies distinct regions in a dilated binary image.
///
/// This function analyzes a dilated image to find connected components that
/// likely represent characters or groups of characters.
///
/// [dilatedMatrixImage] is the preprocessed binary image after dilation.
/// Returns a list of IntRect objects representing the bounding boxes of identified regions.
List<IntRect> findRegions({required Artifact dilatedMatrixImage}) {
  // Clear existing regions
  List<IntRect> regions = [];

  // Create a matrix to track visited pixels
  final Artifact visited = Artifact(
    dilatedMatrixImage.cols,
    dilatedMatrixImage.rows,
  );

  final int width = dilatedMatrixImage.cols;
  final int height = dilatedMatrixImage.rows;
  final Uint8List imageData = dilatedMatrixImage.matrix;
  final Uint8List visitedData = visited.matrix;

  // Scan through each pixel - use direct array access
  for (int y = 0; y < height; y++) {
    final int rowOffset = y * width;
    for (int x = 0; x < width; x++) {
      final int index = rowOffset + x;
      // Check if pixel is on and not visited using direct array access
      if (visitedData[index] == 0 && imageData[index] == 1) {
        // Find region bounds directly without storing all points
        final IntRect rect = floodFillToRect(
          dilatedMatrixImage,
          visited,
          x,
          y,
        );

        if (rect.width > 0 && rect.height > 0) {
          regions.add(rect);
        }
      }
    }
  }

  Artifact.sortRectangles(regions);
  return regions;
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

  // Early bounds check
  if (startX < 0 || startX >= width || startY < 0 || startY >= height) {
    return IntRect.zero;
  }

  // Early check for valid starting pixel
  if (!binaryPixels.cellGet(startX, startY)) {
    return IntRect.zero;
  }

  // Direct access to the underlying arrays
  final Uint8List pixelData = binaryPixels.matrix;
  final Uint8List visitedData = visited.matrix;

  // Initialize bounds to starting point
  int minX = startX;
  int minY = startY;
  int maxX = startX;
  int maxY = startY;

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
      if (pixelData[neighborIndex] == 1 && visitedData[neighborIndex] == 0) {
        visitedData[neighborIndex] = 1;
        queue.add(neighborIndex);
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

///
Artifact matrixFromPoints(List<Point<int>> connectedPoints) {
  // Create a new matrix for the isolated region
  final int minX = connectedPoints.map((point) => point.x).reduce(min);
  final int minY = connectedPoints.map((point) => point.y).reduce(min);
  final int maxX = connectedPoints.map((point) => point.x).reduce(max);
  final int maxY = connectedPoints.map((point) => point.y).reduce(max);

  final int regionWidth = maxX - minX + 1;
  final int regionHeight = maxY - minY + 1;

  final Artifact artifact = Artifact(regionWidth, regionHeight);
  artifact.locationFound = IntOffset(minX, minY);
  artifact.locationAdjusted = artifact.locationFound;

  for (final Point<int> point in connectedPoints) {
    final int localX = (point.x - minX);
    final int localY = (point.y - minY);
    artifact.cellSet(localX, localY, true);
  }
  return artifact;
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
Artifact dilateMatrix({
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

/// Calculates the histogram of a binary image region.
///
/// Iterates over the specified [region] of the [binaryImage] and counts the
/// number of set pixels in each column, storing the results in a list.
///
/// Parameters:
/// - [binaryImage]: The binary image to analyze.
/// - [region]: The rectangular region of the image to analyze.
///
/// Returns:
/// A list of integers representing the histogram of the specified region.
List<int> getHistogramOfRegion(final Artifact binaryImage, IntRect region) {
  final List<int> histogram = [];
  int col = 0;
  for (int x = region.left.toInt(); x < region.right.toInt(); x++) {
    histogram.add(0);
    for (int y = region.top.toInt(); y < region.bottom.toInt(); y++) {
      if (binaryImage.cellGet(x, y)) {
        histogram[col]++;
      }
    }
    col++;
  }

  return histogram;
}

/// Calculates a threshold value for splitting a histogram at its valleys.
///
/// This function analyzes a histogram to find local minima (valleys) and returns
/// a threshold value slightly higher than the smallest valley found.
///
/// Parameters:
/// - [histogram]: A list of integers representing the histogram to analyze.
///
/// Returns:
/// - A threshold value to use for splitting, or -1 if no suitable valley is found
///   or the histogram is too small.
int calculateHistogramValleyThreshold(List<int> histogram) {
  if (histogram.length < 3) {
    return -1;
  }

  // Find all valleys (local minima)
  List<int> valleys = [];
  for (int i = 1; i < histogram.length - 1; i++) {
    if (histogram[i] < histogram[i - 1] && histogram[i] < histogram[i + 1]) {
      valleys.add(histogram[i]);
    }
  }

  // If we found valleys, use the smallest one as threshold
  if (valleys.isNotEmpty) {
    int smallestValley = valleys.reduce(min);
    return (smallestValley * 1.2)
        .toInt(); // Slightly higher than smallest valley
  }

  // If no valleys found, return -1 to indicate that splitting is not possible
  return -1;
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
void offsetMatrices(final List<Artifact> matrices, final int x, final int y) {
  matrices.forEach(
    (matrix) => matrix.locationFound = matrix.locationFound.translate(x, y),
  );
}

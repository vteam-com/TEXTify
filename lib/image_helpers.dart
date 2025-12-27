/// This library is part of the Textify package.
/// Collection of utility functions for image processing and text extraction.
library;

import 'dart:typed_data';
import 'dart:ui';

/// Exports
export 'package:textify/models/int_rect.dart';

/// Converts a color image to a binary (black and white) image.
///
/// This preprocessing step simplifies the image for text recognition by
/// converting it to a binary format where text is represented as black pixels
/// on a white background.
///
/// The function works in three steps:
/// 1. Converts the color image to grayscale using weighted RGB values
/// 2. Applies optional contrast adjustment using the provided contrast parameter
/// 3. Applies adaptive thresholding to convert grayscale to binary
///
/// Parameters:
/// - [inputImage]: The source color image to convert.
/// - [contrast]: Optional contrast adjustment level. 0 means no adjustment,
///   positive values increase contrast, range typically 0-100.
///
/// Returns:
/// A ```Future<Image>``` containing the binary version of the input image.
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
  final ByteData? data = await image.toByteData(
    format: ImageByteFormat.rawRgba,
  );
  return data?.buffer.asUint8List() ?? Uint8List(0);
}

/// Computes the appropriate kernel size for dilation based on image dimensions.
///
/// This function calculates a kernel size proportional to the image dimensions,
/// which is useful for morphological operations like dilation.
///
/// Parameters:
/// - [width]: The width of the image in pixels.
/// - [height]: The height of the image in pixels.
/// - [scaleFactor]: A scaling factor that determines how the kernel size relates
///   to image dimensions. Typically a small value (e.g., 0.01-0.05).
///
/// Returns:
/// An integer representing the computed kernel size, clamped between 1 and the image width.
int computeKernelSize(int width, int height, double scaleFactor) {
  return (scaleFactor * width).round().clamp(1, width);
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

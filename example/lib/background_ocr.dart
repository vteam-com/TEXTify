import 'dart:isolate';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:textify/artifact.dart';
import 'package:textify/artifact_morphology.dart' as morphology;
import 'package:textify/artifact_region.dart';
import 'package:textify/models/int_rect.dart';
import 'package:textify/models/textify_config.dart';
import 'package:textify/textify.dart';

const int _bytesPerPixel = 4;
const int _maxChannelValue = 255;
const int _grayscaleLevels = 256;
const int _grayscaleMidpoint = 128;
const int _channelOffsetRed = 0;
const int _channelOffsetGreen = 1;
const int _channelOffsetBlue = 2;
const double _redLumaWeight = 0.299;
const double _greenLumaWeight = 0.587;
const double _blueLumaWeight = 0.114;
const int _matrixCellOff = 0;
const int _matrixCellOn = 1;

class StepProcessingResult {
  const StepProcessingResult({
    required this.binaryImage,
    required this.dilatedImage,
    required this.regions,
    required this.regionHistograms,
  });

  final Artifact binaryImage;
  final Artifact dilatedImage;
  final List<IntRect> regions;
  final List<List<int>> regionHistograms;
}

Future<Textify> processImageWithBackgroundIsolate({
  required ui.Image image,
  required TextifyConfig config,
  required String characterDefinitionsJson,
  String supportedCharacters = '',
}) async {
  final ByteData? data = await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  if (data == null) {
    throw StateError('Unable to read RGBA bytes from the source image.');
  }

  final Uint8List rgbaBytes = data.buffer.asUint8List();
  final _BackgroundOcrRequest request = _BackgroundOcrRequest(
    rgbaBytes: TransferableTypedData.fromList([rgbaBytes]),
    width: image.width,
    height: image.height,
    config: config,
    characterDefinitionsJson: characterDefinitionsJson,
    supportedCharacters: supportedCharacters,
  );

  return compute<_BackgroundOcrRequest, Textify>(
    _runOcrOnIsolate,
    request,
    debugLabel: 'textify-ocr-worker',
  );
}

Future<StepProcessingResult> processImageForStepsWithBackgroundIsolate({
  required ui.Image image,
  required int kernelSize,
}) async {
  final ByteData? data = await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  if (data == null) {
    throw StateError('Unable to read RGBA bytes from the source image.');
  }

  final Uint8List rgbaBytes = data.buffer.asUint8List();
  final _BackgroundStepRequest request = _BackgroundStepRequest(
    rgbaBytes: TransferableTypedData.fromList([rgbaBytes]),
    width: image.width,
    height: image.height,
    kernelSize: kernelSize,
  );

  return compute<_BackgroundStepRequest, StepProcessingResult>(
    _runStepPipelineOnIsolate,
    request,
    debugLabel: 'textify-steps-worker',
  );
}

Future<Textify> _runOcrOnIsolate(_BackgroundOcrRequest request) async {
  final Uint8List rgbaBytes = request.rgbaBytes.materialize().asUint8List();
  final Artifact imageAsMatrix = _artifactFromRgbaBytes(
    rgbaBytes,
    request.width,
    request.height,
  );

  Textify.characterDefinitions.fromJsonString(request.characterDefinitionsJson);
  final Textify textify = Textify(config: request.config);
  await textify.getTextFromMatrix(
    imageAsMatrix: imageAsMatrix,
    supportedCharacters: request.supportedCharacters,
  );
  return textify;
}

StepProcessingResult _runStepPipelineOnIsolate(_BackgroundStepRequest request) {
  final Uint8List rgbaBytes = request.rgbaBytes.materialize().asUint8List();
  final Artifact binaryImage = _artifactFromRgbaBytes(
    rgbaBytes,
    request.width,
    request.height,
  );
  final int maxKernelSize = max(1, min(binaryImage.cols, binaryImage.rows));
  final int boundedKernelSize = request.kernelSize.clamp(1, maxKernelSize);
  final Artifact dilatedImage = morphology.dilateArtifact(
    matrixImage: binaryImage,
    kernelSize: boundedKernelSize,
  );
  final List<IntRect> regions = dilatedImage.findSubRegions();
  final List<List<int>> regionHistograms = _getHistograms(binaryImage, regions);

  return StepProcessingResult(
    binaryImage: binaryImage,
    dilatedImage: dilatedImage,
    regions: regions,
    regionHistograms: regionHistograms,
  );
}

Artifact _artifactFromRgbaBytes(Uint8List rgbaBytes, int width, int height) {
  if (width <= 0 || height <= 0) {
    return Artifact(0, 0);
  }

  final int pixelCount = width * height;
  final int expectedBytes = pixelCount * _bytesPerPixel;
  if (rgbaBytes.length < expectedBytes) {
    throw ArgumentError(
      'Invalid RGBA length: expected at least $expectedBytes, got ${rgbaBytes.length}.',
    );
  }

  final Uint8List grayscale = Uint8List(pixelCount);
  final List<int> histogram = List<int>.filled(_grayscaleLevels, 0);
  int sumAll = 0;

  int rgbaIndex = 0;
  for (int pixel = 0; pixel < pixelCount; pixel++) {
    final int r = rgbaBytes[rgbaIndex + _channelOffsetRed];
    final int g = rgbaBytes[rgbaIndex + _channelOffsetGreen];
    final int b = rgbaBytes[rgbaIndex + _channelOffsetBlue];
    rgbaIndex += _bytesPerPixel;

    final int gray =
        (_redLumaWeight * r + _greenLumaWeight * g + _blueLumaWeight * b)
            .toInt()
            .clamp(0, _maxChannelValue);
    grayscale[pixel] = gray;
    histogram[gray] += 1;
    sumAll += gray;
  }

  final int threshold = _computeOtsuThreshold(
    histogram: histogram,
    totalPixels: pixelCount,
    sumAll: sumAll,
  );

  final Uint8List binaryMatrix = Uint8List(pixelCount);
  for (int pixel = 0; pixel < pixelCount; pixel++) {
    binaryMatrix[pixel] =
        grayscale[pixel] > threshold ? _matrixCellOff : _matrixCellOn;
  }

  final Artifact artifact = Artifact(width, height);
  artifact.setGrid(binaryMatrix, width);
  return artifact;
}

int _computeOtsuThreshold({
  required List<int> histogram,
  required int totalPixels,
  required int sumAll,
}) {
  if (totalPixels == 0) {
    return _grayscaleMidpoint;
  }

  int sumBackground = 0;
  int weightBackground = 0;
  double maxBetween = -1;
  int bestThreshold = _grayscaleMidpoint;

  for (int threshold = 0; threshold < _grayscaleLevels; threshold++) {
    weightBackground += histogram[threshold];
    if (weightBackground == 0) {
      continue;
    }

    final int weightForeground = totalPixels - weightBackground;
    if (weightForeground == 0) {
      break;
    }

    sumBackground += threshold * histogram[threshold];
    final int sumForeground = sumAll - sumBackground;

    final double meanBackground = sumBackground / weightBackground;
    final double meanForeground = sumForeground / weightForeground;
    final double between = weightBackground *
        weightForeground *
        (meanBackground - meanForeground) *
        (meanBackground - meanForeground);

    if (between > maxBetween) {
      maxBetween = between;
      bestThreshold = threshold;
    }
  }

  return bestThreshold;
}

List<List<int>> _getHistograms(Artifact binaryImage, List<IntRect> regions) {
  final List<List<int>> regionHistograms = [];
  for (final IntRect region in regions) {
    regionHistograms.add(_getHistogramForRegion(binaryImage, region));
  }
  return regionHistograms;
}

List<int> _getHistogramForRegion(Artifact binaryImage, IntRect region) {
  final List<int> histogram = List<int>.filled(region.width, 0);
  int column = 0;
  for (int x = region.left; x < region.right; x++) {
    for (int y = region.top; y < region.bottom; y++) {
      if (binaryImage.cellGet(x, y)) {
        histogram[column]++;
      }
    }
    column++;
  }
  return histogram;
}

class _BackgroundOcrRequest {
  const _BackgroundOcrRequest({
    required this.rgbaBytes,
    required this.width,
    required this.height,
    required this.config,
    required this.characterDefinitionsJson,
    required this.supportedCharacters,
  });

  final TransferableTypedData rgbaBytes;
  final int width;
  final int height;
  final TextifyConfig config;
  final String characterDefinitionsJson;
  final String supportedCharacters;
}

class _BackgroundStepRequest {
  const _BackgroundStepRequest({
    required this.rgbaBytes,
    required this.width,
    required this.height,
    required this.kernelSize,
  });

  final TransferableTypedData rgbaBytes;
  final int width;
  final int height;
  final int kernelSize;
}

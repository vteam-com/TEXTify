/// This library is part of the Textify package.
/// Provides the main interface for text extraction from images.
library;

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

import 'package:textify/bands.dart';
import 'package:textify/character_definitions.dart';
import 'package:textify/correction.dart';
import 'package:textify/models/score_match.dart';
import 'package:textify/models/textify_config.dart';
import 'package:textify/image_helpers.dart';

const int _minLettersForCaseNormalization = 3;
const double _dominantCaseRatio = 0.9;
const int _spaceCodeUnit = 32;
const int _tabCodeUnit = 9;
const int _lineFeedCodeUnit = 10;
const int _carriageReturnCodeUnit = 13;
const int _maxNoiseLineLength = 2;
const double _punctuationHeavyRatioThreshold = 0.3;
const int _regexGroupFirst = 1;
const int _regexGroupSecond = 2;
const int _uppercaseACodeUnit = 65;
const int _uppercaseZCodeUnit = 90;
const int _lowercaseACodeUnit = 97;
const int _lowercaseZCodeUnit = 122;
const int _digitZeroCodeUnit = 48;
const int _digitNineCodeUnit = 57;
const int _asciiCaseOffset = 32;

/// Main OCR class for extracting text from clean digital images.
///
/// Processes images by identifying text regions, organizing them into lines (bands),
/// and recognizing characters using template matching.
class Textify {
  static const double _dilationKernelRatio = 0.02;
  static const double _splitScoreThreshold = 0.4;
  static const double _lowerRightStrokeSwapDelta = 0.06;
  static const double _lowercaseMToUAspectRatioThreshold = 1.05;
  static const double _lowercaseMUScoreDelta = 0.08;
  static const int _lowercaseMToUStemThreshold = 2;
  static const double _mergeScoreThreshold = 0.6;
  static const double _mergeScoreDelta = 0.05;
  static const double _mergeNarrowWidthRatio = 0.6;
  static const double _mergeMaxWidthRatio = 1.3;
  static const double _mergeHScoreDelta = 0.08;

  /// Creates a new instance of Textify with the specified configuration.
  ///
  /// [config] defines the OCR processing settings. If not provided,
  /// uses the balanced configuration with default settings.
  Textify({this.config = const TextifyConfig()});

  /// The configuration settings for this Textify instance.
  final TextifyConfig config;

  /// Stores definitions of characters for matching.
  static final CharacterDefinitions characterDefinitions =
      CharacterDefinitions();

  /// Identified regions on the image after dilation processing.
  List<IntRect> regionsFromDilated = [];

  /// List of text bands identified in the image.
  /// Each band represents a horizontal line of text.
  Bands bands = Bands();

  /// The extracted text from the image after processing.
  String textFound = '';

  /// Timestamp when the text extraction process begins.
  DateTime processBegin = DateTime.now();

  /// Timestamp when the text extraction process ends.
  DateTime processEnd = DateTime.now();

  /// Duration in milliseconds between process start and end.
  ///
  /// Calculates the time taken for text extraction by finding the difference
  /// between processEnd and processBegin timestamps.
  int get duration =>
      processEnd.millisecondsSinceEpoch - processBegin.millisecondsSinceEpoch;

  /// Whether to attempt splitting touching characters.
  /// When true, the system tries to separate characters that are connected.
  bool get innerSplit => config.attemptCharacterSplitting;

  /// Whether to apply dictionary-based text correction.
  ///
  /// When enabled, recognized text is compared against a dictionary
  /// to improve accuracy by correcting likely mis-recognitions.
  bool get applyDictionary => config.applyDictionaryCorrection;

  /// Initializes Textify by loading character definitions from assets.
  ///
  /// [pathToAssetsDefinition] specifies the JSON file containing character matrices.
  /// Returns the initialized Textify instance.
  Future<Textify> init({
    final String pathToAssetsDefinition =
        'packages/textify/assets/matrices.json',
  }) async {
    await characterDefinitions.loadDefinitions(pathToAssetsDefinition);
    return this;
  }

  /// Resets the Textify instance to its initial state.
  /// Clears all bands and extracted text.
  void clear() {
    bands.clear();
    textFound = '';
  }

  /// Width of the character template used for recognition.
  /// Standardized width for comparing characters.
  int get templateWidth => CharacterDefinition.templateWidth;

  /// Height of the character template used for recognition.
  /// Standardized height for comparing characters.
  int get templateHeight => CharacterDefinition.templateHeight;

  /// Total number of artifacts (potential characters) identified.
  int get count => bands.totalArtifacts;

  /// Extracts text from a Flutter Image object.
  ///
  /// [image] is the source image to process.
  /// [supportedCharacters] optionally limits recognition to specific characters.
  /// Returns the extracted text as a string.
  Future<String> getTextFromImage({
    required final ui.Image image,
    final String supportedCharacters = '',
  }) async {
    final ui.Image imageBlackAndWhite = await imageToBlackOnWhite(image);

    final Artifact imageAsArtifact = await Artifact.artifactFromImage(
      imageBlackAndWhite,
    );

    return await getTextFromMatrix(
      imageAsMatrix: imageAsArtifact,
      supportedCharacters: supportedCharacters,
    );
  }

  /// Extracts text from a binary matrix representation.
  ///
  /// [imageAsMatrix] is the binary image data.
  /// [supportedCharacters] optionally limits recognition to specific characters.
  /// Returns the extracted text as a string.
  Future<String> getTextFromMatrix({
    required final Artifact imageAsMatrix,
    final String supportedCharacters = '',
  }) async {
    assert(
      characterDefinitions.count > 0,
      'No character definitions loaded, did you forget to call Init()',
    );

    processBegin = DateTime.now();

    extractBandsAndArtifacts(imageAsMatrix);

    String result = await getTextInBands(
      listOfBands: bands.list,
      supportedCharacters: supportedCharacters,
    );

    processEnd = DateTime.now();

    return result;
  }

  /// Processes image to identify text regions and organize into bands.
  ///
  /// [matrixSourceImage] is the binary image to process.
  /// Updates internal state with found regions and text bands.
  ///
  /// Processes an image to find text regions and organize them into lines.
  ///
  /// Steps: dilate image → find regions → group into text lines (bands)
  void extractBandsAndArtifacts(final Artifact matrixSourceImage) {
    clear();

    int kernelSize = computeKernelSize(
      matrixSourceImage.cols,
      matrixSourceImage.rows,
      _dilationKernelRatio,
    );
    final Artifact dilatedImage = Artifact.dilateArtifact(
      matrixImage: matrixSourceImage,
      kernelSize: kernelSize,
    );

    regionsFromDilated = dilatedImage.findSubRegions();

    bands = Bands.getBandsOfArtifacts(
      matrixSourceImage,
      regionsFromDilated,
      innerSplit,
    );
  }

  /// Calculates similarity scores between a matrix and character templates.
  ///
  /// [templates] are the character definitions to compare against.
  /// [inputMatrix] is the normalized character image.
  /// Returns sorted list of match scores, best matches first.
  static List<ScoreMatch> _getDistanceScores(
    List<CharacterDefinition> templates,
    Artifact inputMatrix,
  ) {
    final List<ScoreMatch> scores = [];
    final Artifact erodedInput = inputMatrix.erodeSoft();
    // Calculate average score for each character definition
    for (final CharacterDefinition template in templates) {
      double totalScore = 0;
      double bestScore = 0;
      int bestMatrixIndex = 0;

      // Find best match and calculate total score
      for (int i = 0; i < template.matrices.length; i++) {
        final Artifact artifact = template.matrices[i];
        final double scoreOriginal =
            Artifact.hammingDistancePercentageOfTwoArtifacts(
              inputMatrix,
              artifact,
            );
        final double scoreEroded =
            Artifact.hammingDistancePercentageOfTwoArtifacts(
              erodedInput,
              artifact,
            );
        final double score = scoreOriginal > scoreEroded
            ? scoreOriginal
            : scoreEroded;

        totalScore += score;

        if (score > bestScore) {
          bestScore = score;
          bestMatrixIndex = i;
        }
      }

      // Calculate weighted score: 70% best match, 30% average across all templates
      final double avgScore = template.matrices.isEmpty
          ? 0
          : totalScore / template.matrices.length;
      final double combinedScore = (bestScore * 0.7) + (avgScore * 0.3);

      scores.add(
        ScoreMatch(
          character: template.character,
          matrixIndex: bestMatrixIndex,
          score: combinedScore,
        ),
      );
    }

    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores;
  }

  /// Converts identified artifacts into text.
  ///
  /// [listOfBands] contains grouped artifacts representing lines of text.
  /// [supportedCharacters] optionally limits recognition to specific characters.
  /// Returns extracted text with preserved line breaks.
  Future<String> getTextInBands({
    required final List<Band> listOfBands,
    final String supportedCharacters = '',
  }) async {
    textFound = '';
    final List<String> linesFound = [];

    for (final Band band in listOfBands) {
      String line = '';

      // Process each band until no more splits are needed
      bool needsReprocessing;
      do {
        needsReprocessing = false;

        // Use index-based loop to handle list modifications
        for (int i = 0; i < band.artifacts.length; i++) {
          final Artifact artifact = band.artifacts[i];

          // Skip artifacts that have already been processed
          if (artifact.matchingCharacter.isNotEmpty) {
            continue;
          }

          final List<ScoreMatch> scores = getMatchingScoresOfNormalizedMatrix(
            artifact,
            supportedCharacters,
          );

          if (scores.isEmpty) {
            continue;
          }

          if (_tryMergeAdjacentLineLikeArtifacts(
            band,
            i,
            artifact,
            scores.first.score,
            supportedCharacters,
          )) {
            needsReprocessing = true;
            break;
          }

          if (scores.first.score < _splitScoreThreshold) {
            artifact.needsInspection = true;
            final List<Artifact> artifactsFromColumns = band.splitChunk(
              artifact,
            );

            if (artifactsFromColumns.isNotEmpty) {
              band.replaceOneArtifactWithMore(artifact, artifactsFromColumns);
              needsReprocessing = true;
              break; // Exit the loop to restart with the new artifacts
            }
          }

          artifact.matchingScore = scores.first.score;
          artifact.matchingCharacter = scores.first.character;
        }
      } while (needsReprocessing);

      // Build the final line from processed artifacts
      band.sortArtifactsLeftToRight();
      for (final Artifact artifact in band.artifacts) {
        line += artifact.matchingCharacter;
      }

      linesFound.add(line);
    }

    textFound += linesFound.join('\n');
    textFound = applyCorrection(textFound, applyDictionary);
    textFound = _postProcessText(textFound);

    return textFound.trim();
  }

  bool _tryMergeAdjacentLineLikeArtifacts(
    Band band,
    int index,
    Artifact current,
    double currentScore,
    String supportedCharacters,
  ) {
    if (index >= band.artifacts.length - 1) {
      return false;
    }

    final Artifact next = band.artifacts[index + 1];
    if (next.matchingCharacter.isNotEmpty) {
      return false;
    }

    final bool lineLikePair =
        current.isConsideredLine() && next.isConsideredLine();
    final int avgWidth = band.averageWidth;
    final bool narrowPair =
        avgWidth > 0 &&
        current.rectFound.width <= (avgWidth * _mergeNarrowWidthRatio) &&
        next.rectFound.width <= (avgWidth * _mergeNarrowWidthRatio);

    final int gap = next.rectFound.left - current.rectFound.right;
    final int maxGap = band.averageKerning <= 0
        ? max(1, avgWidth ~/ 2)
        : max(1, min(avgWidth ~/ 2, band.averageKerning * 2));
    if (gap < 0 || gap > maxGap) {
      return false;
    }

    final bool widthEligible =
        avgWidth > 0 &&
        (current.rectFound.width + next.rectFound.width + gap) <=
            (avgWidth * _mergeMaxWidthRatio);

    if (!lineLikePair && !narrowPair && !widthEligible) {
      return false;
    }

    final List<ScoreMatch> nextScores = getMatchingScoresOfNormalizedMatrix(
      next,
      supportedCharacters,
    );
    if (nextScores.isEmpty) {
      return false;
    }

    final Artifact merged = Artifact.fromMatrix(current);
    merged.mergeArtifact(next);

    final List<ScoreMatch> mergedScores = getMatchingScoresOfNormalizedMatrix(
      merged,
      supportedCharacters,
    );
    if (mergedScores.isEmpty) {
      return false;
    }

    final ScoreMatch bestMergedMatch = mergedScores.first;
    final double bestMerged = bestMergedMatch.score;
    final double bestIndividual = currentScore > nextScores.first.score
        ? currentScore
        : nextScores.first.score;

    if (bestMerged < _mergeScoreThreshold) {
      return false;
    }

    if (bestMergedMatch.character == 'H' || bestMergedMatch.character == 'h') {
      band.artifacts[index] = merged;
      band.artifacts.removeAt(index + 1);
      return true;
    }

    ScoreMatch? hMatch;
    for (final ScoreMatch score in mergedScores) {
      if (score.character == 'H' || score.character == 'h') {
        hMatch = score;
        break;
      }
    }
    if (hMatch != null &&
        hMatch.score >= _mergeScoreThreshold &&
        (bestMerged - hMatch.score) <= _mergeHScoreDelta) {
      band.artifacts[index] = merged;
      band.artifacts.removeAt(index + 1);
      return true;
    }
    if ((bestMerged - bestIndividual) < _mergeScoreDelta) {
      return false;
    }

    band.artifacts[index] = merged;
    band.artifacts.removeAt(index + 1);
    return true;
  }

  /// Finds which character templates best match the given artifact.
  ///
  /// [artifact] is the normalized character image.
  /// [supportedCharacters] optionally limits matching to specific characters.
  /// Returns sorted list of match scores, best matches first.
  List<ScoreMatch> getMatchingScoresOfNormalizedMatrix(
    final Artifact artifact, [
    final String supportedCharacters = '',
  ]) {
    final int numberOfEnclosure = artifact.enclosures;
    final bool hasVerticalLineOnTheLeftSide = artifact.verticalLineLeft;
    final bool hasVerticalLineOnTheRightSide = artifact.verticalLineRight;
    final bool punctuation = artifact.isPunctuation();

    const double percentageNeeded = 0.5;
    const int totalChecks = 4;

    List<CharacterDefinition> qualifiedTemplates = characterDefinitions
        .definitions
        .where((final CharacterDefinition template) {
          if (supportedCharacters.isNotEmpty &&
              !supportedCharacters.contains(template.character)) {
            return false;
          }

          int matchingChecks = 0;
          if (numberOfEnclosure == template.enclosures) {
            matchingChecks++;
          }
          if (punctuation == template.isPunctuation) {
            matchingChecks++;
          }
          if (hasVerticalLineOnTheLeftSide == template.lineLeft) {
            matchingChecks++;
          }
          if (hasVerticalLineOnTheRightSide == template.lineRight) {
            matchingChecks++;
          }

          final double matchPercentage = matchingChecks / totalChecks;
          return matchPercentage >= percentageNeeded;
        })
        .toList();

    final Artifact resizedArtifact = artifact.createNormalizeMatrix(
      templateWidth,
      templateHeight,
    );

    final IntRect content = artifact.getContentRect();
    final double inputAspectRatio = content.isEmpty
        ? 1.0
        : content.width / content.height;

    final List<ScoreMatch> scores = _getDistanceScores(
      qualifiedTemplates,
      resizedArtifact,
    );

    scores.sort((a, b) => b.score.compareTo(a.score));
    if (resizedArtifact.hasLowerRightStroke()) {
      _promoteRWhenLowerRightStroke(scores);
    }
    _promoteUWhenNarrowLowercaseM(
      scores,
      inputAspectRatio,
      resizedArtifact.countVerticalStems(),
    );
    return scores;
  }

  static void _promoteRWhenLowerRightStroke(List<ScoreMatch> scores) {
    if (scores.isEmpty) {
      return;
    }

    final int pIndex = scores.indexWhere(
      (score) => score.character == 'P' || score.character == 'p',
    );
    final int rIndex = scores.indexWhere(
      (score) => score.character == 'R' || score.character == 'r',
    );

    if (pIndex != 0 || rIndex < 0) {
      return;
    }

    final double pScore = scores[pIndex].score;
    final double rScore = scores[rIndex].score;
    if ((pScore - rScore) <= _lowerRightStrokeSwapDelta) {
      final ScoreMatch r = scores.removeAt(rIndex);
      scores.insert(0, r);
    }
  }

  static void _promoteUWhenNarrowLowercaseM(
    List<ScoreMatch> scores,
    double inputAspectRatio,
    int stemCount,
  ) {
    if (scores.isEmpty) {
      return;
    }

    final int mIndex = scores.indexWhere((score) => score.character == 'm');
    final int uIndex = scores.indexWhere((score) => score.character == 'u');

    if (mIndex != 0 || uIndex < 0) {
      return;
    }

    if (stemCount <= _lowercaseMToUStemThreshold) {
      final ScoreMatch u = scores.removeAt(uIndex);
      scores.insert(0, u);
      return;
    }

    if (inputAspectRatio >= _lowercaseMToUAspectRatioThreshold) {
      return;
    }

    final double mScore = scores[mIndex].score;
    final double uScore = scores[uIndex].score;
    if ((mScore - uScore) <= _lowercaseMUScoreDelta) {
      final ScoreMatch u = scores.removeAt(uIndex);
      scores.insert(0, u);
    }
  }

  /// Loads an image from the asset bundle.
  ///
  /// [assetPath] is the path to the image asset.
  /// Returns the loaded image as a ```Future<ui.Image>.```
  static Future<ui.Image> loadImageFromAssets(String assetPath) async {
    final assetImage = AssetImage(assetPath);
    final completer = Completer<ui.Image>();
    assetImage
        .resolve(ImageConfiguration.empty)
        .addListener(
          ImageStreamListener((info, _) => completer.complete(info.image)),
        );
    return completer.future;
  }
}

String _postProcessText(String text) {
  if (text.isEmpty) {
    return text;
  }

  final List<String> lines = text.split('\n');
  final List<String> processed = <String>[];
  for (final String line in lines) {
    String value = _normalizeLineCase(line);
    value = _normalizeNumericGaps(value);
    value = _normalizeDigitSegments(value);
    processed.add(value);
  }

  final List<String> merged = _mergeNoiseLines(processed);
  final String joined = merged.join('\n');
  final String normalized = _normalizePunctuationHeavyText(joined);
  final String lettersFixed = _normalizeLetterConfusions(normalized);
  return _normalizePunctuationSpacing(lettersFixed);
}

String _normalizeLineCase(String line) {
  int letters = 0;
  int upper = 0;
  int lower = 0;
  int? firstLetterCode;

  for (int i = 0; i < line.length; i++) {
    final int code = line.codeUnitAt(i);
    if (_isUpper(code)) {
      letters++;
      upper++;
      firstLetterCode ??= code;
    } else if (_isLower(code)) {
      letters++;
      lower++;
      firstLetterCode ??= code;
    }
  }

  if (letters < _minLettersForCaseNormalization) {
    return line;
  }

  final double upperRatio = upper / letters;
  final double lowerRatio = lower / letters;

  if (upperRatio >= _dominantCaseRatio) {
    return line.toUpperCase();
  }
  if (lowerRatio >= _dominantCaseRatio && firstLetterCode != null) {
    if (_isLower(firstLetterCode)) {
      return _sentenceCase(line);
    }
    return line;
  }

  return line;
}

String _normalizeDigitSegments(String line) {
  final StringBuffer out = StringBuffer();
  final StringBuffer buffer = StringBuffer();

  void flushBuffer() {
    if (buffer.isEmpty) {
      return;
    }
    String segment = buffer.toString();
    buffer.clear();

    int digits = 0;
    int letters = 0;
    for (int i = 0; i < segment.length; i++) {
      final int code = segment.codeUnitAt(i);
      if (_isDigit(code)) {
        digits++;
      } else if (_isLetter(code)) {
        letters++;
      }
    }

    if (digits > 0 && digits >= letters) {
      final StringBuffer mapped = StringBuffer();
      for (int i = 0; i < segment.length; i++) {
        final String ch = segment[i];
        mapped.write(_digitConfusionMap[ch] ?? ch);
      }
      segment = mapped.toString();
    }

    out.write(segment);
  }

  for (int i = 0; i < line.length; i++) {
    final int code = line.codeUnitAt(i);
    if (_isLetter(code) || _isDigit(code)) {
      buffer.writeCharCode(code);
    } else {
      flushBuffer();
      out.writeCharCode(code);
    }
  }
  flushBuffer();

  return out.toString();
}

String _normalizeNumericGaps(String line) {
  if (line.isEmpty) {
    return line;
  }

  bool hasNonDigitToken = false;
  for (int i = 0; i < line.length; i++) {
    final int code = line.codeUnitAt(i);
    if (!_isDigit(code) &&
        code != _spaceCodeUnit &&
        code != _tabCodeUnit &&
        code != _lineFeedCodeUnit &&
        code != _carriageReturnCodeUnit) {
      hasNonDigitToken = true;
      break;
    }
  }

  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < line.length; i++) {
    final String ch = line[i];
    final int code = ch.codeUnitAt(0);
    final bool prevDigit = i > 0 && _isDigit(line.codeUnitAt(i - 1));
    final bool nextDigit =
        i + 1 < line.length && _isDigit(line.codeUnitAt(i + 1));

    if (_digitNonAlnumMap.containsKey(ch) && (prevDigit || nextDigit)) {
      buffer.write(_digitNonAlnumMap[ch]);
      continue;
    }

    if (code == _spaceCodeUnit ||
        code == _tabCodeUnit ||
        code == _lineFeedCodeUnit ||
        code == _carriageReturnCodeUnit) {
      buffer.write(ch);
      continue;
    }

    buffer.write(ch);
  }

  final String withMappedNonAlnum = buffer.toString();

  if (!hasNonDigitToken) {
    return withMappedNonAlnum.replaceAll(RegExp(r'\s+'), '');
  }

  return withMappedNonAlnum.replaceAllMapped(
    RegExp(r'(\d)\s+([A-Za-z0-9])(?=\d)'),
    (Match match) {
      final String left = match.group(_regexGroupFirst) ?? '';
      final String mid = match.group(_regexGroupSecond) ?? '';
      final String mapped = _digitConfusionMap[mid] ?? mid;
      return '$left.$mapped';
    },
  );
}

List<String> _mergeNoiseLines(List<String> lines) {
  if (lines.isEmpty) {
    return lines;
  }

  final List<String> merged = <String>[];
  int i = 0;
  while (i < lines.length) {
    final String current = lines[i];
    if (_isNoiseLine(current)) {
      final List<String> noise = <String>[];
      int j = i;
      while (j < lines.length && _isNoiseLine(lines[j])) {
        noise.add(lines[j]);
        j++;
      }

      if (j < lines.length) {
        String next = lines[j];
        final String prefix = _inferPrefixFromNoise(noise, next);
        if (prefix.isNotEmpty) {
          next = '$prefix$next';
        }
        lines[j] = next;
      }
      i = j;
      continue;
    }

    merged.add(current);
    i++;
  }

  return merged;
}

bool _isNoiseLine(String line) {
  final String trimmed = line.trim();
  if (trimmed.isEmpty) {
    return true;
  }
  if (trimmed.length > _maxNoiseLineLength) {
    return false;
  }

  for (int i = 0; i < trimmed.length; i++) {
    final int code = trimmed.codeUnitAt(i);
    if (_isLetter(code) || _isDigit(code)) {
      if (!_noiseLetters.contains(trimmed[i])) {
        return false;
      }
      continue;
    }
    if (!_noisePunctuation.contains(trimmed[i])) {
      return false;
    }
  }
  return true;
}

String _inferPrefixFromNoise(List<String> noiseLines, String nextLine) {
  if (nextLine.isEmpty) {
    return '';
  }
  final int firstCode = nextLine.codeUnitAt(0);
  if (!_isLower(firstCode)) {
    return '';
  }

  bool hasVertical = false;
  bool hasHorizontal = false;
  for (final String line in noiseLines) {
    for (int i = 0; i < line.length; i++) {
      final String ch = line[i];
      if (_noiseVertical.contains(ch)) {
        hasVertical = true;
      }
      if (_noiseHorizontal.contains(ch)) {
        hasHorizontal = true;
      }
    }
  }

  if (hasVertical && hasHorizontal) {
    return 'T';
  }
  if (hasVertical) {
    return 'I';
  }
  return '';
}

String _normalizePunctuationHeavyText(String text) {
  int alnum = 0;
  int nonWhitespace = 0;
  for (int i = 0; i < text.length; i++) {
    final int code = text.codeUnitAt(i);
    if (code != _spaceCodeUnit &&
        code != _tabCodeUnit &&
        code != _lineFeedCodeUnit &&
        code != _carriageReturnCodeUnit) {
      nonWhitespace++;
    }
    if (_isLetter(code) || _isDigit(code)) {
      alnum++;
    }
  }

  if (text.isEmpty || nonWhitespace == 0) {
    return text;
  }

  final double ratio = alnum / nonWhitespace;
  if (ratio < _punctuationHeavyRatioThreshold) {
    return text.replaceAll(RegExp(r'\s+'), '');
  }
  return text;
}

String _normalizePunctuationSpacing(String text) {
  if (text.isEmpty) {
    return text;
  }

  String value = text.replaceAllMapped(
    RegExp(r'\s+([,.;:!?])'),
    (match) => match.group(1) ?? '',
  );
  value = value.replaceAllMapped(
    RegExp(r'\s+([)\]\}])'),
    (match) => match.group(1) ?? '',
  );
  return value;
}

String _normalizeLetterConfusions(String text) {
  if (text.isEmpty) {
    return text;
  }

  // Common split of 'H' into 'I]' when the crossbar is faint.
  return text.replaceAllMapped(
    RegExp(r'([A-Za-z])I\]([A-Za-z])'),
    (match) =>
        '${match.group(_regexGroupFirst)}H${match.group(_regexGroupSecond)}',
  );
}

bool _isUpper(int code) =>
    code >= _uppercaseACodeUnit && code <= _uppercaseZCodeUnit;
bool _isLower(int code) =>
    code >= _lowercaseACodeUnit && code <= _lowercaseZCodeUnit;
bool _isLetter(int code) => _isUpper(code) || _isLower(code);
bool _isDigit(int code) =>
    code >= _digitZeroCodeUnit && code <= _digitNineCodeUnit;

String _sentenceCase(String line) {
  final StringBuffer buffer = StringBuffer();
  bool capitalized = false;
  for (int i = 0; i < line.length; i++) {
    final String ch = line[i];
    final int code = ch.codeUnitAt(0);
    if (!capitalized && _isLetter(code)) {
      buffer.writeCharCode(_isLower(code) ? code - _asciiCaseOffset : code);
      capitalized = true;
      continue;
    }
    buffer.write(ch);
  }
  return buffer.toString();
}

const Map<String, String> _digitConfusionMap = {
  'O': '0',
  'o': '0',
  'I': '1',
  'l': '1',
  'L': '1',
  't': '1',
  'T': '1',
  'Z': '2',
  'z': '2',
  'A': '8',
  'a': '8',
  'S': '5',
  's': '5',
};

const Map<String, String> _digitNonAlnumMap = {
  ']': '1',
  '[': '1',
  '|': '1',
  '!': '1',
};

const Set<String> _noiseLetters = {'i', 'l', 'I', 'L', 't', 'T'};

const Set<String> _noisePunctuation = {
  '*',
  '-',
  '_',
  '|',
  '!',
  '\'',
  '`',
  '.',
  ',',
};

const Set<String> _noiseVertical = {'i', 'l', 'I', 'L', '|', '!'};

const Set<String> _noiseHorizontal = {'*', '-', '_'};

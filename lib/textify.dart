/// This library is part of the Textify package.
/// Provides the main interface for text extraction from images.
library;

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:textify/artifact_analysis.dart';
import 'package:textify/artifact_grid_transform.dart';
import 'package:textify/artifact_morphology.dart';
import 'package:textify/artifact_projection.dart';
import 'package:textify/artifact_region.dart';
import 'package:textify/bands.dart';
import 'package:textify/char_utils.dart';
import 'package:textify/character_definitions.dart';
import 'package:textify/constants.dart';
import 'package:textify/correction.dart';
import 'package:textify/image_helpers.dart';
import 'package:textify/models/score_match.dart';
import 'package:textify/models/textify_config.dart';
import 'package:textify/textify_post_process.dart';

part 'textify_refinement_helpers.dart';

/// Main OCR class for extracting text from clean digital images.
///
/// Processes images by identifying text regions, organizing them into lines (bands),
/// and recognizing characters using template matching.
class Textify {
  static const double _lowerRightStrokeSwapDelta = 0.06;
  static const double _lowercaseMToUAspectRatioThreshold = 1.05;
  static const double _lowercaseMUScoreDelta = 0.08;
  static const int _lowercaseMToUStemThreshold = 2;
  static const double _letterOverPunctuationDelta = 0.05;
  static const double _letterDominanceRatio = 0.6;
  static const double _bandContextPromotionDelta = 0.22;
  static const double _digitContextPromotionDelta = 0.12;
  static const int _digitContextMinDigits = 2;
  static const double _leadingLowercaseUpperTokenDelta = 0.05;
  static const double _lowercaseILPromotionDelta = 0.04;
  static const double _lowercaseOEPromotionDelta = 0.02;
  static const double _lowercaseESparseLowerThirdMax = 0.35;
  static const int _lowercaseTokenMaxUppercase = 1;
  static const int _lowercaseTokenRefinementMinLength = 3;
  static const double _punctuationToLetterPromotionDelta = 0.10;
  static const double _punctuationBandPromotionDelta = 0.06;
  static const double _punctuationBandBlankScoreThreshold = 0.20;
  static const double _punctuationDominanceRatio = 0.70;
  static const double _punctuationCompetitiveDelta = 0.08;
  static const double _punctuationLowOnlyTopRatio = 0.50;
  static const double _punctuationShortDotHeightRatio = 0.24;
  static const double _punctuationFlatHeightRatio = 0.15;
  static const double _punctuationTallMarkHeightRatio = 0.65;
  static const double _punctuationDescenderBottomRatio = 0.95;
  static const double _punctuationWideEnclosureWidthRatio = 1.35;
  static const int _stackedPunctuationMinComponents = 2;
  static const double _structuredTokenCasePromotionDelta = 0.10;
  static const double _codeTokenStructurePromotionDelta = 0.06;
  static const int _codeTokenRefinementMinLength = 6;
  static const int _codeTokenRefinementMinLetters = 2;
  static const int _codeTokenRefinementMinDigits = 2;
  static const double _structuredSeparatorMaxAspectRatio = 0.30;
  static const int _structuredSeparatorMinimumArtifacts = 3;
  static const int _structuredTitleCaseTokenMinLength = 3;
  static const int _structuredUppercaseTokenMinLength = 4;
  static const int _structuredUppercaseTokenMinUppercase = 2;
  static const int _leadingLowercaseUpperTokenLength = 2;
  static const double _uppercaseDominanceRatio = 0.70;
  static const double _uppercaseEFSwapDelta = 0.02;
  static const double _uppercaseFSparseLowerThirdMax = 0.33;
  static const double _uppercaseTIProxyDelta = 0.12;
  static const double _uppercaseWeakLScoreThreshold = 0.45;
  static const double _uppercaseWeakMScoreThreshold = 0.45;
  static const double _uppercaseMUProxyDelta = 0.03;
  static const double _uppercaseUProxyDelta = 0.10;
  static const double _uppercaseMUSwapDelta = 0.02;
  static const double _uppercaseUFromLMaxAspectRatio = 1.05;
  static const double _uppercaseUFromMMaxAspectRatio = 0.68;
  static const int _uppercaseUStemThreshold = 2;
  static const int _uppercaseMStemThreshold = 3;
  static const double _uppercaseTrailingISplitWidthRatio = 1.35;
  static const double _uppercaseTrailingISplitMaxOriginalScore = 0.50;
  static const double _uppercaseTrailingISplitMinGain = 0.12;
  static const double _uppercaseTrailingISplitMinIScore = 0.70;
  static const int _uppercaseTrailingISplitMinPartWidth = 4;
  static const double _uppercaseLASplitMaxOriginalScore = 0.50;
  static const double _uppercaseLASplitMinCurrentWidthRatio = 1.25;
  static const double _uppercaseLASplitMaxFragmentWidthRatio = 0.70;
  static const double _uppercaseLASplitSlashCandidateDelta = 0.18;
  static const double _uppercaseLASplitMinGain = 0.14;
  static const double _uppercaseLASplitMinLScore = 0.54;
  static const double _uppercaseLASplitMinAScore = 0.68;
  static const int _uppercaseLASplitMinPartWidth = 4;
  static const int _uppercaseProseMinSpaces = 4;
  static const int _uppercaseProseMinLetters = 12;
  static const int _mergeGapWidthDivisor = 2;
  static const double _mergeScoreThreshold = 0.6;
  static const double _mergeScoreDelta = 0.05;
  static const int _suspiciousSplitMinEnclosures = 2;
  static const double _suspiciousSplitWidthRatio = 1.5;
  static const double _mergeNarrowWidthRatio = 0.6;
  static const double _mergeMaxWidthRatio = 1.3;
  static const int _weakArtifactMaxWidth = 10;
  static const int _punctuationOnlyBandMinCharacters = 4;
  static const double _structuralTieBreakDelta = 0.02;
  static const double _runnerUpStructuralTieBreakDelta = 0.05;
  static const double _scoreEqualityTolerance = 1e-9;
  static const int _minimumTieBreakCandidates = 2;
  static const int _characterCategoryLetter = 1;
  static const int _characterCategoryDigit = 2;
  static const int _characterCategoryOther = 3;

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
      TextifyErrors.noCharacterDefinitions,
    );

    processBegin = DateTime.now();

    extractBandsAndArtifacts(imageAsMatrix);

    String result =
        await getTextInBands(
          listOfBands: bands.list,
          supportedCharacters: supportedCharacters,
        ).timeout(
          Duration(milliseconds: config.maxProcessingTimeMs),
          onTimeout: () => textFound,
        );

    processEnd = DateTime.now();

    return result;
  }

  /// Processes image to identify text regions and organize into bands.
  ///
  /// [matrixSourceImage] is the binary image to process.
  /// Updates internal state with found regions and text bands.
  ///
  /// Uses histogram projection (XY-cut) to segment the image:
  /// 1. Horizontal projection finds text line rows
  /// 2. Connected components within each line find individual characters
  /// 3. Existing merge logic handles multi-component characters (i, j, etc.)
  void extractBandsAndArtifacts(final Artifact matrixSourceImage) {
    clear();

    final Artifact cleanedSourceImage = config.excludeLongLines
        ? matrixSourceImage.removeDecorativeLineComponents()
        : matrixSourceImage;

    // Step 1: Find text lines via horizontal projection (replaces dilation)
    final List<IntRect> textLineRects = findTextLineRects(cleanedSourceImage);
    regionsFromDilated = textLineRects;

    // Step 2: For each text line, extract character artifacts via
    // connected components.
    for (final IntRect lineRect in textLineRects) {
      final Artifact lineArtifact = cleanedSourceImage.extractSubGrid(
        rect: lineRect,
      );

      bands.add(
        Band.splitArtifactIntoBand(
          regionMatrix: lineArtifact,
          offset: lineRect.topLeft,
        ),
      );
    }

    // Clean up bands
    bands.removeEmptyBands();

    for (final Band band in bands.list) {
      for (final a in band.artifacts) {
        a.locationAdjusted = IntOffset(a.locationFound.x, a.locationFound.y);
      }
      band.sortArtifactsLeftToRight();
    }

    Bands.sortVerticallyThenHorizontally(bands.list);

    for (final Band band in bands.list) {
      band.padVerticallyArtifactToMatchTheBand();
      band.identifySpacesInBand();
      band.packArtifactLeftToRight();
    }
  }

  /// Maximum number of candidates to run full Hamming comparison on.
  static const int _histogramTopK = 15;

  /// Confidence threshold below which the fallback expansion runs.
  static const double _histogramFallbackThreshold = 0.6;

  /// Calculates similarity scores between a matrix and character templates.
  ///
  /// Uses histogram pre-ranking to limit expensive Hamming comparisons
  /// to the top-K most promising candidates.
  ///
  /// [templates] are the character definitions to compare against.
  /// [inputMatrix] is the normalized character image.
  /// Returns sorted list of match scores, best matches first.
  static List<ScoreMatch> _getDistanceScores(
    List<CharacterDefinition> templates,
    Artifact inputMatrix,
  ) {
    if (templates.isEmpty) {
      return const [];
    }

    // Pre-rank by histogram similarity (cheap: 100 int comparisons each)
    final List<int> inputColHist = _columnHistogram(inputMatrix);
    final List<int> inputRowHist = _rowHistogram(inputMatrix);

    final List<_HistogramRankedCandidate> ranked = [];
    for (int i = 0; i < templates.length; i++) {
      final double histScore = templates[i].histogramSimilarity(
        inputColHist,
        inputRowHist,
      );
      ranked.add(_HistogramRankedCandidate(index: i, histScore: histScore));
    }
    ranked.sort((a, b) => b.histScore.compareTo(a.histScore));

    // Run Hamming on top-K candidates
    final int firstBatch = min(_histogramTopK, ranked.length);
    final List<ScoreMatch> scores = _hammingScoreBatch(
      templates,
      inputMatrix,
      ranked,
      0,
      firstBatch,
    );

    scores.sort((a, b) => b.score.compareTo(a.score));

    // Fallback: if best score is weak, expand to remaining candidates
    if (scores.isNotEmpty &&
        scores.first.score < _histogramFallbackThreshold &&
        firstBatch < ranked.length) {
      final List<ScoreMatch> fallbackScores = _hammingScoreBatch(
        templates,
        inputMatrix,
        ranked,
        firstBatch,
        ranked.length,
      );
      scores.addAll(fallbackScores);
      scores.sort((a, b) => b.score.compareTo(a.score));
    }

    return scores;
  }

  /// Runs Hamming distance comparison for a range of ranked candidates.
  static List<ScoreMatch> _hammingScoreBatch(
    List<CharacterDefinition> templates,
    Artifact inputMatrix,
    List<_HistogramRankedCandidate> ranked,
    int startIndex,
    int endIndex,
  ) {
    final Artifact erodedInput = inputMatrix.erodeSoft();
    final List<ScoreMatch> scores = [];

    for (int r = startIndex; r < endIndex; r++) {
      final CharacterDefinition template = templates[ranked[r].index];
      double totalScore = 0;
      double bestScore = 0;
      int bestMatrixIndex = 0;

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

    return scores;
  }

  /// Computes column histogram (pixel count per column) for an artifact.
  static List<int> _columnHistogram(Artifact artifact) {
    final List<int> hist = List<int>.filled(artifact.cols, 0);
    for (int x = 0; x < artifact.cols; x++) {
      for (int y = 0; y < artifact.rows; y++) {
        if (artifact.cellGet(x, y)) {
          hist[x]++;
        }
      }
    }
    return hist;
  }

  /// Computes row histogram (pixel count per row) for an artifact.
  static List<int> _rowHistogram(Artifact artifact) {
    final List<int> hist = List<int>.filled(artifact.rows, 0);
    for (int y = 0; y < artifact.rows; y++) {
      for (int x = 0; x < artifact.cols; x++) {
        if (artifact.cellGet(x, y)) {
          hist[y]++;
        }
      }
    }
    return hist;
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

          final bool shouldAttemptSplit =
              scores.first.score < config.matchingThreshold ||
              _shouldInspectArtifactForSplit(
                band,
                artifact,
                scores.first.character,
              );

          if (shouldAttemptSplit) {
            artifact.needsInspection = true;
            final List<Artifact> artifactsFromColumns = band.splitChunk(
              artifact,
            );

            if (artifactsFromColumns.isNotEmpty &&
                _splitImprovesScore(
                  artifactsFromColumns,
                  scores.first.score,
                  supportedCharacters,
                )) {
              band.replaceOneArtifactWithMore(artifact, artifactsFromColumns);
              needsReprocessing = true;
              break; // Exit the loop to restart with the new artifacts
            }
          }

          final double weakArtifactThreshold = max(
            0,
            config.matchingThreshold - _mergeScoreDelta,
          );
          final bool weakTinyArtifact =
              scores.first.score < weakArtifactThreshold &&
              (artifact.rectFound.width <= _weakArtifactMaxWidth ||
                  artifact.isPunctuation());
          if (weakTinyArtifact) {
            continue;
          }

          artifact.matchingScore = scores.first.score;
          artifact.matchingCharacter = scores.first.character;
        }
      } while (needsReprocessing);

      // Build the final line from processed artifacts
      band.sortArtifactsLeftToRight();
      _reMergeConsecutiveVerticalStrokes(band);
      _reMergeSplitFragments(band);
      _refineDigitsInDigitContext(band);
      _recoverStructuredHorizontalSeparators(band);
      _refinePunctuationInLetterContext(band);
      _reMergeSplitFragments(band);
      _refineUppercaseInUppercaseContext(band);
      _splitMergedTrailingUppercaseI(this, band);
      _repairSplitUppercaseLA(this, band);
      _refineLowercaseILInLowercaseContext(band);
      _refineLowercaseLikeTokens(this, band);
      _refineLeadingLowercaseUpperToken(band);
      _refineTitleCaseTokensInMixedCaseBand(this, band);
      _refineStructuredFieldTokenCase(this, band);
      _refineCodeLikeTokenCharacters(this, band);
      _refinePunctuationDominantBand(band);
      _removeFalseSpacesInPunctuationBand(band);
      for (int i = 0; i < band.artifacts.length; i++) {
        final Artifact artifact = band.artifacts[i];
        line += artifact.matchingCharacter;
        if (i >= band.artifacts.length - 1) {
          continue;
        }

        final Artifact next = band.artifacts[i + 1];
        if (_shouldInsertResidualSpace(band, artifact, next)) {
          line += ' ';
        }
      }

      linesFound.add(line);
    }

    textFound += linesFound.join('\n');
    textFound = applyCorrection(textFound, applyDictionary);
    textFound = postProcessText(textFound, applyDictionary: applyDictionary);

    return textFound.trim();
  }

  /// Attempts to merge adjacent line-like fragments into a single glyph.
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

    if (!lineLikePair && !narrowPair && !widthEligible && gap > 1) {
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

    final Map<String, double> structuralMatchByCharacter = {};
    final List<CharacterDefinition> qualifiedTemplates =
        <CharacterDefinition>[];
    for (final CharacterDefinition template
        in characterDefinitions.definitions) {
      if (supportedCharacters.isNotEmpty &&
          !supportedCharacters.contains(template.character)) {
        continue;
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
      if (matchPercentage < percentageNeeded) {
        continue;
      }

      qualifiedTemplates.add(template);
      structuralMatchByCharacter[template.character] = matchPercentage;
    }

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
    _applyStructuralTieBreak(scores, structuralMatchByCharacter);
    _promoteLetterOverPunctuation(scores);
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

  /// Re-evaluates punctuation/symbol matches when surrounded by letters.
  ///
  /// When a band is dominated by letter characters, isolated punctuation
  /// matches are likely OCR misreads. This pass re-scores those artifacts
  /// and promotes the best letter alternative if one exists.
  void _refinePunctuationInLetterContext(Band band) {
    final List<Artifact> artifacts = band.artifacts;
    if (artifacts.length < _minimumTieBreakCandidates) {
      return;
    }

    // Count how many matched characters are letters
    int letterCount = 0;
    for (final Artifact a in artifacts) {
      if (isLetter(a.matchingCharacter)) {
        letterCount++;
      }
    }

    // Only act when band is predominantly letters
    if (letterCount < artifacts.length * _letterDominanceRatio) {
      return;
    }

    for (int i = 0; i < artifacts.length; i++) {
      final Artifact artifact = artifacts[i];
      if (isLetter(artifact.matchingCharacter) ||
          isDigit(artifact.matchingCharacter) ||
          artifact.matchingCharacter == ' ' ||
          _isVerticalStrokeChar(artifact.matchingCharacter)) {
        continue;
      }

      // Check if neighbors are letters
      final bool leftIsLetter =
          i > 0 && isLetter(artifacts[i - 1].matchingCharacter);
      final bool rightIsLetter =
          i < artifacts.length - 1 &&
          isLetter(artifacts[i + 1].matchingCharacter);
      if (!leftIsLetter && !rightIsLetter) {
        continue;
      }

      // Re-score and pick best letter only if competitive with original
      final double originalScore = artifact.matchingScore;
      final List<ScoreMatch> scores = getMatchingScoresOfNormalizedMatrix(
        artifact,
      );
      final double allowedPromotionDelta = leftIsLetter && rightIsLetter
          ? _bandContextPromotionDelta
          : _punctuationToLetterPromotionDelta;
      for (final ScoreMatch score in scores) {
        if (!isLetter(score.character)) {
          continue;
        }
        if ((originalScore - score.score) > allowedPromotionDelta) {
          break;
        }

        artifact.matchingCharacter = score.character;
        artifact.matchingScore = score.score;
        break;
      }
    }
  }

  /// Promotes digit alternatives inside digit-heavy runs and digit islands.
  void _refineDigitsInDigitContext(Band band) {
    final List<Artifact> artifacts = band.artifacts;
    if (artifacts.length < _minimumTieBreakCandidates) {
      return;
    }

    int start = 0;
    while (start < artifacts.length) {
      while (start < artifacts.length &&
          !_isAlphanumericArtifact(artifacts[start])) {
        start++;
      }
      if (start >= artifacts.length) {
        return;
      }

      int end = start;
      int digitCount = 0;
      int letterCount = 0;
      while (end < artifacts.length &&
          _isAlphanumericArtifact(artifacts[end])) {
        if (isDigit(artifacts[end].matchingCharacter)) {
          digitCount++;
        } else if (isLetter(artifacts[end].matchingCharacter)) {
          letterCount++;
        }
        end++;
      }

      final bool runDigitDominant =
          digitCount >= _digitContextMinDigits && digitCount >= letterCount;

      for (int i = start; i < end; i++) {
        final Artifact artifact = artifacts[i];
        if (!isLetter(artifact.matchingCharacter)) {
          continue;
        }

        final bool leftDigit =
            i > start && isDigit(artifacts[i - 1].matchingCharacter);
        final bool rightDigit =
            i + 1 < end && isDigit(artifacts[i + 1].matchingCharacter);
        if (!runDigitDominant && !(leftDigit && rightDigit)) {
          continue;
        }

        final List<ScoreMatch> scores = getMatchingScoresOfNormalizedMatrix(
          artifact,
        );
        for (final ScoreMatch score in scores) {
          if (!isDigit(score.character)) {
            continue;
          }
          if ((artifact.matchingScore - score.score) >
              _digitContextPromotionDelta) {
            break;
          }

          artifact.matchingCharacter = score.character;
          artifact.matchingScore = score.score;
          break;
        }
      }

      start = end + 1;
    }
  }

  /// Restores dropped hyphen-like separators between alphanumeric neighbors.
  void _recoverStructuredHorizontalSeparators(Band band) {
    final List<Artifact> artifacts = band.artifacts;
    if (artifacts.length < _structuredSeparatorMinimumArtifacts) {
      return;
    }

    for (int i = 1; i < artifacts.length - 1; i++) {
      final Artifact artifact = artifacts[i];
      if (artifact.matchingCharacter.isNotEmpty) {
        continue;
      }
      if (artifact.getContentRect().isEmpty ||
          artifact.aspectRatioOfContent() >
              _structuredSeparatorMaxAspectRatio) {
        continue;
      }

      final Artifact left = artifacts[i - 1];
      final Artifact right = artifacts[i + 1];
      if (!_isAlphanumericArtifact(left) || !_isAlphanumericArtifact(right)) {
        continue;
      }
      if (!isDigit(left.matchingCharacter) &&
          !isDigit(right.matchingCharacter)) {
        continue;
      }

      artifact.matchingCharacter = '-';
      artifact.matchingScore =
          _scoreForCharacter(
            getMatchingScoresOfNormalizedMatrix(artifact),
            '-',
          ) ??
          0;
    }
  }

  /// Promotes tokens like `oK` to `OK` when the uppercase alternative is near.
  void _refineLeadingLowercaseUpperToken(Band band) {
    final List<Artifact> artifacts = band.artifacts;
    if (artifacts.length < _leadingLowercaseUpperTokenLength) {
      return;
    }

    for (int i = 0; i < artifacts.length - 1; i++) {
      final Artifact current = artifacts[i];
      final Artifact next = artifacts[i + 1];
      if (!isLowercaseLetter(current.matchingCharacter) ||
          !isUppercaseLetter(next.matchingCharacter)) {
        continue;
      }

      final bool startsToken =
          i == 0 || !isLetter(artifacts[i - 1].matchingCharacter);
      final bool endsToken =
          i + _leadingLowercaseUpperTokenLength >= artifacts.length ||
          !isLetter(
            artifacts[i + _leadingLowercaseUpperTokenLength].matchingCharacter,
          );
      if (!startsToken || !endsToken) {
        continue;
      }

      final String uppercaseCandidate = current.matchingCharacter.toUpperCase();
      final double? uppercaseScore = _scoreForCharacter(
        getMatchingScoresOfNormalizedMatrix(current),
        uppercaseCandidate,
      );
      if (uppercaseScore == null ||
          (current.matchingScore - uppercaseScore) >
              _leadingLowercaseUpperTokenDelta) {
        continue;
      }

      current.matchingCharacter = uppercaseCandidate;
      current.matchingScore = uppercaseScore;
    }
  }

  static bool _isAlphanumericArtifact(Artifact artifact) {
    final String character = artifact.matchingCharacter;
    return isLetter(character) || isDigit(character);
  }

  /// Promotes `i` over `l` inside long lowercase prose words when scores are close.
  void _refineLowercaseILInLowercaseContext(Band band) {
    if (!_looksLikeLowercaseProseBand(band)) {
      return;
    }

    final List<Artifact> artifacts = band.artifacts;
    for (int i = 1; i < artifacts.length - 1; i++) {
      final Artifact artifact = artifacts[i];
      if (artifact.matchingCharacter != 'l') {
        continue;
      }

      final Artifact previous = artifacts[i - 1];
      final Artifact next = artifacts[i + 1];
      if (!isLowercaseLetter(previous.matchingCharacter) ||
          !isLowercaseLetter(next.matchingCharacter)) {
        continue;
      }

      final List<ScoreMatch> scores = getMatchingScoresOfNormalizedMatrix(
        artifact,
      );
      final double? iScore = _scoreForCharacter(scores, 'i');
      if (iScore == null ||
          (artifact.matchingScore - iScore) > _lowercaseILPromotionDelta) {
        continue;
      }

      artifact.matchingCharacter = 'i';
      artifact.matchingScore = iScore;
    }
  }

  /// Re-merges consecutive narrow vertical-stroke artifacts (e.g. two 'I's)
  /// that may be halves of a split character like 'H'.
  ///
  /// After matching, two narrow artifacts both scoring as 'I' may actually
  /// be a single character whose crossbar was too faint to connect them.
  /// This pass tries merging each pair and accepts if the merged score
  /// is better than either individual.
  void _reMergeConsecutiveVerticalStrokes(Band band) {
    final int avgWidth = band.averageWidth;
    if (avgWidth <= 0) {
      return;
    }

    for (int i = 0; i < band.artifacts.length - 1; i++) {
      final Artifact current = band.artifacts[i];
      final Artifact next = band.artifacts[i + 1];

      if (!_isVerticalStrokeChar(current.matchingCharacter) ||
          !_isVerticalStrokeChar(next.matchingCharacter)) {
        continue;
      }

      // Both must be narrow relative to the band average
      if (current.rectFound.width > avgWidth * _mergeNarrowWidthRatio ||
          next.rectFound.width > avgWidth * _mergeNarrowWidthRatio) {
        continue;
      }

      // Gap must be reasonable
      final int gap = next.rectFound.left - current.rectFound.right;
      if (gap < 0 || gap > avgWidth ~/ _mergeGapWidthDivisor) {
        continue;
      }

      final Artifact merged = Artifact.fromMatrix(current);
      merged.mergeArtifact(next);

      final List<ScoreMatch> mergedScores = getMatchingScoresOfNormalizedMatrix(
        merged,
      );
      if (mergedScores.isEmpty ||
          mergedScores.first.score < _mergeScoreThreshold) {
        continue;
      }

      // Only accept if the merged result is a different character
      if (mergedScores.first.character == 'I') {
        continue;
      }

      // Accept the merge
      merged.matchingCharacter = mergedScores.first.character;
      merged.matchingScore = mergedScores.first.score;
      band.artifacts[i] = merged;
      band.artifacts.removeAt(i + 1);
      i--; // Re-check from same position
    }
  }

  /// Whether a character is a vertical-stroke glyph (I, l, |, 1) that could
  /// be half of a split two-stroke character like 'H'.
  static bool _isVerticalStrokeChar(String ch) =>
      ch == 'I' || ch == 'l' || ch == '|' || ch == '1' || ch == ']';

  /// Re-merges adjacent artifacts that originated from a split when the merged
  /// result scores better than the worse of the two individual pieces.
  ///
  /// After splitting, a single character may be broken into two fragments
  /// that each match a wrong template. This pass tries merging consecutive
  /// split-origin artifacts and accepts the merge when the combined score
  /// exceeds the individual scores.
  void _reMergeSplitFragments(Band band) {
    final int avgWidth = band.averageWidth;
    if (avgWidth <= 0) {
      return;
    }

    for (int i = 0; i < band.artifacts.length - 1; i++) {
      final Artifact current = band.artifacts[i];
      final Artifact next = band.artifacts[i + 1];

      // Only consider pairs where both came from a split
      if (!current.wasPartOfSplit || !next.wasPartOfSplit) {
        continue;
      }

      // Fragments must be adjacent or nearly so
      final int gap = next.rectFound.left - current.rectFound.right;
      if (gap < 0 || gap > avgWidth ~/ _mergeGapWidthDivisor) {
        continue;
      }

      final Artifact merged = Artifact.fromMatrix(current);
      merged.mergeArtifact(next);

      final List<ScoreMatch> mergedScores = getMatchingScoresOfNormalizedMatrix(
        merged,
      );
      if (mergedScores.isEmpty) {
        continue;
      }

      final double mergedScore = mergedScores.first.score;
      final double worseIndividual = current.matchingScore < next.matchingScore
          ? current.matchingScore
          : next.matchingScore;

      // Accept merge if it scores better than the worse individual piece
      if (mergedScore > worseIndividual) {
        merged.matchingCharacter = mergedScores.first.character;
        merged.matchingScore = mergedScore;
        band.artifacts[i] = merged;
        band.artifacts.removeAt(i + 1);
        i--; // Re-check from same position
      }
    }
  }

  /// Removes inserted spaces from dense punctuation-only bands.
  ///
  /// Space detection runs before recognition, so isolated punctuation lines can
  /// pick up false spaces from slightly wider glyph gaps. Once the band resolves
  /// to punctuation-only content, those synthetic spaces are more harmful than
  /// helpful.
  static void _removeFalseSpacesInPunctuationBand(Band band) {
    int punctuationCount = 0;
    int alphaNumericCount = 0;
    int spaceCount = 0;

    for (final Artifact artifact in band.artifacts) {
      final String character = artifact.matchingCharacter;
      if (character == ' ') {
        spaceCount++;
        continue;
      }
      if (isLetter(character) || isDigit(character)) {
        alphaNumericCount++;
        continue;
      }
      if (character.isNotEmpty) {
        punctuationCount++;
      }
    }

    if (spaceCount == 0 || alphaNumericCount > 0) {
      return;
    }
    if (punctuationCount < _punctuationOnlyBandMinCharacters) {
      return;
    }

    band.artifacts.removeWhere((artifact) => artifact.matchingCharacter == ' ');
  }

  /// Reclaims punctuation in bands that are already punctuation-dominant.
  ///
  /// Generated symbol rows can still pick up letters like `I`, `l`, or `e`
  /// because the global letter-over-punctuation tie-break is tuned for prose.
  /// Once a band is clearly punctuation-heavy, prefer competitive punctuation
  /// candidates again and allow low-confidence punctuation to replace blanks.
  void _refinePunctuationDominantBand(Band band) {
    int punctuationCount = 0;
    int alphaNumericCount = 0;

    for (final Artifact artifact in band.artifacts) {
      final String character = artifact.matchingCharacter;
      if (_isPunctuationLikeCharacter(character)) {
        punctuationCount++;
        continue;
      }
      if (isLetter(character) || isDigit(character)) {
        alphaNumericCount++;
      }
    }

    final int nonSpaceCount = punctuationCount + alphaNumericCount;
    if (nonSpaceCount < _punctuationOnlyBandMinCharacters) {
      return;
    }
    if (punctuationCount / nonSpaceCount < _punctuationDominanceRatio) {
      return;
    }

    for (final Artifact artifact in band.artifacts) {
      final List<ScoreMatch> scores = getMatchingScoresOfNormalizedMatrix(
        artifact,
      );
      if (scores.isEmpty) {
        continue;
      }

      final ScoreMatch? punctuationCandidate = _bestPunctuationCandidate(
        scores,
        artifact,
        band,
      );
      if (punctuationCandidate == null) {
        continue;
      }

      final String current = artifact.matchingCharacter;
      if (current.isEmpty || current == ' ') {
        if (_shouldForcePunctuationGeometryOverride(artifact) ||
            punctuationCandidate.score >= _punctuationBandBlankScoreThreshold) {
          artifact.matchingCharacter = punctuationCandidate.character;
          artifact.matchingScore = punctuationCandidate.score;
        }
        continue;
      }

      if (_isPunctuationLikeCharacter(current)) {
        if (punctuationCandidate.character != current &&
            (_shouldForcePunctuationGeometryOverride(artifact) ||
                (artifact.matchingScore - punctuationCandidate.score) <=
                    _punctuationCompetitiveDelta)) {
          artifact.matchingCharacter = punctuationCandidate.character;
          artifact.matchingScore = punctuationCandidate.score;
        }
        continue;
      }

      if ((artifact.matchingScore - punctuationCandidate.score) <=
          _punctuationBandPromotionDelta) {
        artifact.matchingCharacter = punctuationCandidate.character;
        artifact.matchingScore = punctuationCandidate.score;
      }
    }
  }

  /// Returns the strongest punctuation candidate for a punctuation-heavy band.
  ///
  /// Starts from the punctuation-only subset of [scores], then lets the
  /// geometry-based classifier override the raw top punctuation match when the
  /// artifact shape strongly suggests a specific symbol class.
  static ScoreMatch? _bestPunctuationCandidate(
    List<ScoreMatch> scores,
    Artifact artifact,
    Band band,
  ) {
    final List<ScoreMatch> punctuationScores = scores
        .where((score) => _isPunctuationLikeCharacter(score.character))
        .toList();
    if (punctuationScores.isEmpty) {
      return null;
    }

    final ScoreMatch best = punctuationScores.first;
    final IntRect content = artifact.getContentRect();
    if (content.isEmpty) {
      return best;
    }

    final double rows = max(1, artifact.rows).toDouble();
    final double topRatio = content.top / rows;
    final double bottomRatio = content.bottom / rows;
    final double heightRatio = content.height / rows;
    final double widthRatio = band.averageWidth <= 0
        ? 1.0
        : artifact.rectFound.width / band.averageWidth;
    final int componentCount = artifact.findSubArtifacts().where((part) {
      return part.isNotEmpty;
    }).length;

    final ScoreMatch? geometryPick = _pickPunctuationByGeometry(
      punctuationScores,
      artifact,
      topRatio,
      bottomRatio,
      heightRatio,
      widthRatio,
      componentCount,
    );
    return geometryPick ?? best;
  }

  /// Uses band-relative geometry to separate similar punctuation symbols.
  ///
  /// The heuristic distinguishes low marks, flat horizontals, stacked-dot
  /// marks, and enclosed symbols so punctuation-only rows are not forced to
  /// rely on prose-oriented score ordering alone.
  static ScoreMatch? _pickPunctuationByGeometry(
    List<ScoreMatch> punctuationScores,
    Artifact artifact,
    double topRatio,
    double bottomRatio,
    double heightRatio,
    double widthRatio,
    int componentCount,
  ) {
    final ScoreMatch best = punctuationScores.first;

    if (topRatio >= _punctuationLowOnlyTopRatio) {
      if (heightRatio <= _punctuationShortDotHeightRatio) {
        return _scoreMatchForCharacter(punctuationScores, '.') ??
            _scoreMatchForCharacter(punctuationScores, ',') ??
            best;
      }
      return _scoreMatchForCharacter(punctuationScores, ',') ??
          _scoreMatchForCharacter(punctuationScores, '.') ??
          best;
    }

    if (heightRatio <= _punctuationFlatHeightRatio) {
      return _scoreMatchForCharacter(punctuationScores, '-') ??
          _scoreMatchForCharacter(punctuationScores, '=') ??
          best;
    }

    if (componentCount >= _stackedPunctuationMinComponents) {
      if (bottomRatio >= _punctuationDescenderBottomRatio) {
        return _scoreMatchForCharacter(punctuationScores, ';') ??
            _scoreMatchForCharacter(punctuationScores, '!') ??
            _scoreMatchForCharacter(punctuationScores, ':') ??
            best;
      }
      if (heightRatio >= _punctuationTallMarkHeightRatio) {
        return _scoreMatchForCharacter(punctuationScores, '!') ??
            _scoreMatchForCharacter(punctuationScores, ':') ??
            best;
      }
      return _scoreMatchForCharacter(punctuationScores, ':') ??
          _scoreMatchForCharacter(punctuationScores, ';') ??
          best;
    }

    if (artifact.enclosures > 0) {
      final ScoreMatch? atCandidate = _scoreMatchForCharacter(
        punctuationScores,
        '@',
      );
      if (atCandidate != null &&
          widthRatio >= _punctuationWideEnclosureWidthRatio &&
          _isCompetitivePunctuationCandidate(best, atCandidate)) {
        return atCandidate;
      }

      final ScoreMatch? dollarCandidate = _scoreMatchForCharacter(
        punctuationScores,
        r'$',
      );
      if (dollarCandidate != null &&
          _isCompetitivePunctuationCandidate(best, dollarCandidate)) {
        return dollarCandidate;
      }
    }

    return null;
  }

  static bool _isCompetitivePunctuationCandidate(
    ScoreMatch best,
    ScoreMatch candidate,
  ) {
    return (best.score - candidate.score) <= _punctuationCompetitiveDelta;
  }

  /// Returns true when punctuation geometry should override score thresholds.
  ///
  /// This is reserved for shapes that are unusually distinctive in
  /// punctuation-only bands, such as low-only marks and very flat horizontals.
  static bool _shouldForcePunctuationGeometryOverride(Artifact artifact) {
    final IntRect content = artifact.getContentRect();
    if (content.isEmpty) {
      return false;
    }

    final double rows = max(1, artifact.rows).toDouble();
    final double topRatio = content.top / rows;
    final double heightRatio = content.height / rows;
    return topRatio >= _punctuationLowOnlyTopRatio ||
        heightRatio <= _punctuationFlatHeightRatio;
  }

  static ScoreMatch? _scoreMatchForCharacter(
    List<ScoreMatch> scores,
    String character,
  ) {
    for (final ScoreMatch score in scores) {
      if (score.character == character) {
        return score;
      }
    }
    return null;
  }

  static bool _isPunctuationLikeCharacter(String character) {
    return character.isNotEmpty &&
        character != ' ' &&
        !isLetter(character) &&
        !isDigit(character);
  }

  /// Returns true when a wide multi-enclosure artifact deserves split rescue.
  ///
  /// This keeps the late split path focused on glyphs that likely contain
  /// multiple joined letters, such as `MB` being matched as a single `E`.
  bool _shouldInspectArtifactForSplit(
    Band band,
    Artifact artifact,
    String bestCharacter,
  ) {
    if (artifact.enclosures < _suspiciousSplitMinEnclosures) {
      return false;
    }

    final int avgWidth = band.averageWidth;
    if (avgWidth <= 0 ||
        artifact.rectFound.width <
            max(
              avgWidth + 1,
              (avgWidth * _suspiciousSplitWidthRatio).round(),
            )) {
      return false;
    }

    final CharacterDefinition? bestDefinition = characterDefinitions
        .getDefinition(bestCharacter);
    if (bestDefinition == null) {
      return false;
    }

    return artifact.enclosures > bestDefinition.enclosures;
  }

  /// Returns true only if splitting an artifact into [parts] produces a mean
  /// score strictly better than [originalScore].
  ///
  /// This prevents the split cascade where a low-scoring character is broken
  /// into several fragments that each score even lower.
  bool _splitImprovesScore(
    List<Artifact> parts,
    double originalScore,
    String supportedCharacters,
  ) {
    double total = 0;
    for (final Artifact part in parts) {
      final List<ScoreMatch> s = getMatchingScoresOfNormalizedMatrix(
        part,
        supportedCharacters,
      );
      total += s.isEmpty ? 0 : s.first.score;
    }
    return (total / parts.length) > originalScore;
  }

  /// Returns true when a remaining wide gap should be treated as a space.
  static bool _shouldInsertResidualSpace(
    Band band,
    Artifact current,
    Artifact next,
  ) {
    if (!_looksLikeUppercaseProseBand(band) &&
        !_looksLikeLowercaseProseBand(band)) {
      return false;
    }
    if (current.matchingCharacter == ' ' || next.matchingCharacter == ' ') {
      return false;
    }
    if ((!isLetter(current.matchingCharacter) &&
            !isDigit(current.matchingCharacter)) ||
        (!isLetter(next.matchingCharacter) &&
            !isDigit(next.matchingCharacter))) {
      return false;
    }

    final int gap = next.rectFound.left - current.rectFound.right;
    if (gap <= 0) {
      return false;
    }

    final int avgWidth = band.averageWidth;
    final int avgKerning = band.averageKerning;
    final int threshold = max(
      1,
      max((avgWidth * 0.45).floor(), avgKerning + 2),
    );
    return gap >= threshold;
  }

  /// Returns true when a band looks like a long all-uppercase prose line.
  static bool _looksLikeUppercaseProseBand(Band band) {
    int spaceCount = 0;
    int letterCount = 0;

    for (final Artifact artifact in band.artifacts) {
      final String ch = artifact.matchingCharacter;
      if (ch == ' ') {
        spaceCount++;
        continue;
      }
      if (ch == '0') {
        letterCount++;
        continue;
      }
      if (!isUppercaseLetter(ch)) {
        return false;
      }
      letterCount++;
    }

    return spaceCount >= _uppercaseProseMinSpaces &&
        letterCount >= _uppercaseProseMinLetters;
  }

  /// Returns true when a band looks like a long all-lowercase prose line.
  static bool _looksLikeLowercaseProseBand(Band band) {
    int spaceCount = 0;
    int letterCount = 0;

    for (final Artifact artifact in band.artifacts) {
      final String ch = artifact.matchingCharacter;
      if (ch == ' ') {
        spaceCount++;
        continue;
      }
      if (!isLowercaseLetter(ch)) {
        return false;
      }
      letterCount++;
    }

    return spaceCount >= _uppercaseProseMinSpaces &&
        letterCount >= _uppercaseProseMinLetters;
  }

  /// Promotes lowercase-matched artifacts to their uppercase equivalent when
  /// the band is predominantly uppercase.
  ///
  /// Arial and similar fonts have uppercase/lowercase glyphs that look nearly
  /// identical at small sizes. If ≥ [_uppercaseDominanceRatio] of letter
  /// matches in a band are uppercase, re-score any lowercase artifacts and
  /// accept the uppercase alternative when the score gap is within
  /// [_bandContextPromotionDelta].
  void _refineUppercaseInUppercaseContext(Band band) {
    final List<Artifact> artifacts = band.artifacts;
    if (artifacts.length < _minimumTieBreakCandidates) {
      return;
    }

    int upperCount = 0;
    int letterCount = 0;
    for (final Artifact a in artifacts) {
      if (isUppercaseLetter(a.matchingCharacter)) {
        upperCount++;
        letterCount++;
      } else if (isLowercaseLetter(a.matchingCharacter)) {
        letterCount++;
      }
    }

    if (letterCount == 0) {
      return;
    }
    if (upperCount / letterCount < _uppercaseDominanceRatio) {
      return;
    }

    final bool uppercaseProseBand = _looksLikeUppercaseProseBand(band);

    for (final Artifact artifact in artifacts) {
      if (!isLetter(artifact.matchingCharacter)) {
        continue;
      }

      final double originalScore = artifact.matchingScore;
      final List<ScoreMatch> scores = getMatchingScoresOfNormalizedMatrix(
        artifact,
      );
      if (uppercaseProseBand && artifact.matchingCharacter == 'T') {
        final double? iScore = _scoreForCharacter(scores, 'I');
        final double? lProxyScore = _scoreForCharacter(scores, 'l');
        final double? uppercaseIProxyScore = iScore ?? lProxyScore;
        if (uppercaseIProxyScore != null &&
            artifact.countVerticalStems() == 1 &&
            !artifact.hasTopHeavyHorizontalBar() &&
            (originalScore - uppercaseIProxyScore) <= _uppercaseTIProxyDelta) {
          artifact.matchingCharacter = 'I';
          artifact.matchingScore = uppercaseIProxyScore;
          continue;
        }
      }

      if (artifact.matchingCharacter == 'E') {
        final double? fScore = _scoreForCharacter(scores, 'F');
        if (fScore != null &&
            (originalScore - fScore) <= _uppercaseEFSwapDelta &&
            _lowerThirdDensity(artifact) <= _uppercaseFSparseLowerThirdMax) {
          artifact.matchingCharacter = 'F';
          artifact.matchingScore = fScore;
          continue;
        }
      }

      if (artifact.matchingCharacter == 'L') {
        final double? uProxyScore = _scoreForCharacter(scores, 'u');
        if (uProxyScore != null &&
            originalScore <= _uppercaseWeakLScoreThreshold &&
            artifact.countVerticalStems() >= _uppercaseUStemThreshold &&
            artifact.aspectRatioOfContent() <= _uppercaseUFromLMaxAspectRatio &&
            (originalScore - uProxyScore) <= _uppercaseUProxyDelta) {
          artifact.matchingCharacter = 'U';
          artifact.matchingScore = uProxyScore;
          continue;
        }
      }

      if (artifact.matchingCharacter == 'M') {
        final double? uScore = _scoreForCharacter(scores, 'U');
        if (uScore != null &&
            originalScore <= _uppercaseWeakMScoreThreshold &&
            artifact.countVerticalStems() >= _uppercaseMStemThreshold &&
            artifact.aspectRatioOfContent() <= _uppercaseUFromMMaxAspectRatio &&
            (originalScore - uScore) <= _uppercaseMUSwapDelta) {
          artifact.matchingCharacter = 'U';
          artifact.matchingScore = uScore;
          continue;
        }
      }

      if (!isLowercaseLetter(artifact.matchingCharacter)) {
        continue;
      }

      if (artifact.matchingCharacter == 'm') {
        final double? uProxyScore = _scoreForCharacter(scores, 'u');
        if (uProxyScore != null &&
            originalScore <= _uppercaseWeakMScoreThreshold &&
            artifact.countVerticalStems() >= _uppercaseMStemThreshold &&
            artifact.aspectRatioOfContent() <= _uppercaseUFromMMaxAspectRatio &&
            (originalScore - uProxyScore) <= _uppercaseMUProxyDelta) {
          artifact.matchingCharacter = 'U';
          artifact.matchingScore = uProxyScore;
          continue;
        }
      }

      for (final ScoreMatch score in scores) {
        if (isUppercaseLetter(score.character) &&
            (originalScore - score.score) <= _bandContextPromotionDelta) {
          artifact.matchingCharacter = score.character;
          artifact.matchingScore = score.score;
          break;
        }
      }
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

/// Internal helper for histogram-based candidate ranking.
class _HistogramRankedCandidate {
  const _HistogramRankedCandidate({
    required this.index,
    required this.histScore,
  });

  /// Index into the qualified templates list.
  final int index;

  /// Histogram similarity score (0.0 to 1.0).
  final double histScore;
}

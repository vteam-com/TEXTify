/// This library is part of the Textify package.
/// Provides the Artifact class for representing and manipulating 2D grids of boolean values.
/// The resulting output of Textify is a list of Artifacts.
library;

import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:textify/image_helpers.dart';

/// Represents a 2D grid of boolean values, primarily used for image processing
/// and pattern recognition tasks.
///
/// This class provides various ways to create, manipulate, and analyze boolean matrices,
/// including methods for resizing, comparing, and extracting information from the grid.
class Artifact {
  static const int _bytesPerPixel = 4;
  static const int _pixelOffValue = 0;
  static const int _pixelOnValue = 1;
  static const int _blackChannelValue = 0;

  static const int _noContentSentinel = -1;
  static const int _maxDiscardableArea = 2;
  static const double _centerDivisor = 2.0;

  static const double _lineAspectRatioMin = 0.09;
  static const double _lineAspectRatioMax = 50.0;
  static const double _punctuationHeightRatio = 0.40;

  static const double _sameLineVerticalThreshold = 10.0;
  static const double _defaultRectangleSortThreshold = 5.0;

  /// Main constructor
  Artifact(this.cols, int rows) {
    _matrix = Uint8List(rows * cols);
  }

  /// Creates a new [Artifact] instance from an existing [Artifact].
  ///
  /// This factory method creates a new [Artifact] instance based on the provided [value] artifact.
  /// It copies the grid data and the rectangle properties from the input artifact.
  ///
  /// Parameters:
  /// - [value]: The source [Artifact] instance to copy from.
  ///
  /// Returns:
  /// A new [Artifact] instance with the same grid data and rectangle as the input artifact.
  ///
  /// Note: This method creates a deep copy of the grid data.
  ///
  /// Example:
  /// ```dart
  /// Artifact original = Artifact(/* ... */);
  /// Artifact copy = Artifact.fromMatrix(original);
  /// ```
  factory Artifact.fromMatrix(final Artifact value) {
    // Create a new Artifact instance with the same dimensions as the source.
    final Artifact artifact = Artifact(value.cols, value.rows);
    // Deep copy the matrix data.
    artifact._matrix = Uint8List.fromList(value._matrix);
    // Copy other relevant properties.
    artifact.locationFound = value.locationFound;
    artifact.locationAdjusted = value.locationAdjusted;
    artifact.matchingCharacter = value.matchingCharacter;
    artifact.matchingScore = value.matchingScore;
    artifact.needsInspection = value.needsInspection;
    artifact.wasPartOfSplit = value.wasPartOfSplit;
    artifact.font = value.font;
    return artifact;
  }

  /// Creates an Artifact from an ASCII representation.
  ///
  /// [template] A list of strings where '#' represents true and any other character represents false.
  factory Artifact.fromAsciiDefinition(final List<String> template) {
    final int rows = template.length;
    final int cols = template[0].length;

    final Artifact artifact = Artifact(cols, rows);

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        artifact.cellSet(x, y, template[y][x] == '#');
      }
    }
    return artifact;
  }

  /// Creates an Artifact from a multi-line ASCII string representation.
  ///
  /// This factory method splits the input string by newline characters and
  /// creates a matrix where '#' represents true and any other character represents false.
  ///
  /// Parameters:
  /// - [input]: A string containing newline-separated rows of ASCII characters.
  ///
  /// Returns:
  /// A new [Artifact] instance representing the ASCII pattern.
  factory Artifact.fromAsciiWithNewlines(final String input) {
    final List<String> template = input.split('\n');
    final Artifact artifact = Artifact.fromAsciiDefinition(template);
    return artifact;
  }

  /// Creates an Artifact from JSON data.
  ///
  /// [json] A map containing 'rows', 'cols', and 'data' keys.
  factory Artifact.fromJson(final Map<String, dynamic> json) {
    // determine the mandatory cols/width of the matrix
    final int cols = (json['cols'] as int?) ?? 0;
    final Artifact artifact = Artifact(cols, 0);
    artifact.font = json['font'] ?? '';
    artifact._matrix = Uint8List.fromList(
      (json['data'] as List<dynamic>).expand((final dynamic row) {
        return row
            .toString()
            .split('')
            .map((cell) => cell == '#' ? _pixelOnValue : _pixelOffValue);
      }).toList(),
    );
    return artifact;
  }

  /// Creates an Artifact from a Uint8List, typically used for image data.
  ///
  /// [pixels] A Uint8List representing pixel data.
  /// [width] The width of the image.
  factory Artifact.fromUint8List(final Uint8List pixels, final int width) {
    return Artifact.fromFlatListOfBool([
      for (int i = 0; i < pixels.length; i += _bytesPerPixel)
        pixels[i] == _blackChannelValue,
    ], width);
  }

  /// Creates an Artifact from a flat list of boolean values.
  ///
  /// [inputList] A flat list of boolean values.
  /// [width] The width of the resulting matrix.
  factory Artifact.fromFlatListOfBool(
    final List<bool> inputList,
    final int width,
  ) {
    final rows = inputList.length ~/ width;

    final Artifact artifact = Artifact(width, rows);

    for (int y = 0; y < rows; y++) {
      final List<bool> values = inputList.sublist(y * width, (y + 1) * width);
      for (int x = 0; x < values.length; x++) {
        artifact.cellSet(x, y, values[x]);
      }
    }
    return artifact;
  }

  /// Creates a new [Artifact] from a list of connected points.
  ///
  /// This factory method takes a list of points that form a connected region and
  /// creates a new [Artifact] that contains just this region.
  ///
  /// Parameters:
  /// - [connectedPoints]: A list of ```Point<int>``` representing connected cells.
  ///
  /// Returns:
  /// A new [Artifact] containing only the connected region, with its location
  /// set to the top-left corner of the bounding box of the points.
  factory Artifact.fromPoints(List<Point<int>> connectedPoints) {
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

  /// The character that this artifact matches.
  String matchingCharacter = '';

  /// The score of the match
  double matchingScore = 0;

  /// Tag the artifact as needing more attention during inspection
  bool needsInspection = false;

  /// Indicates whether this artifact was created as part of a splitting operation
  bool wasPartOfSplit = false;

  /// Empty the content
  void clear() {
    cols = 0;
    _matrix = Uint8List(0);
  }

  /// Counts the number of "on" pixels within an optional rectangle.
  ///
  /// If [rect] is omitted, counts all pixels in the artifact.
  int countOnPixels({IntRect? rect}) {
    final IntRect bounds = rect ?? IntRect.fromLTWH(0, 0, cols, rows);
    if (bounds.isEmpty) {
      return 0;
    }

    int count = 0;
    for (int y = bounds.top; y < bounds.bottom; y++) {
      for (int x = bounds.left; x < bounds.right; x++) {
        if (cellGet(x, y)) {
          count++;
        }
      }
    }
    return count;
  }

  /// Returns a string representation of this artifact.
  ///
  /// The string includes information about the matched character, position,
  /// dimensions, emptiness status, enclosures, and vertical line detection.
  ///
  /// Returns a formatted string with artifact details.
  @override
  String toString() {
    return '"$matchingCharacter" left:${locationFound.x} top:${locationFound.y} CW:${rectFound.width} CH:${rectFound.height} isEmpty:$isEmpty E:${cachedEnclosures ?? "?"} LL:${cachedVerticalLineLeft ?? "?"} LR:${cachedVerticalLineRight ?? "?"}';
  }

  /// Font this template is based on.
  String font = '';

  /// The number of columns in the grid.
  int cols = 0;

  /// The number of rows in the grid.
  int get rows => _matrix.isEmpty ? 0 : _matrix.length ~/ cols;

  /// Flat row-major buffer representing the grid (0 = off, 1 = on).
  Uint8List _matrix = Uint8List(0);

  /// The raw grid buffer.
  Uint8List get matrix => _matrix;

  /// Returns true when another artifact has identical normalized pixel data.
  bool hasSameMatrixData(Artifact other) {
    return cols == other.cols && listEquals(_matrix, other._matrix);
  }

  /// The location of this artifact in the source image.
  IntOffset locationFound = const IntOffset();

  /// The rectangle location of this artifact.
  IntRect get rectFound =>
      IntRect.fromLTWH(locationFound.x, locationFound.y, cols, rows);

  /// The adjusted location.
  IntOffset locationAdjusted = const IntOffset();

  /// The rectangle location after adjustment.
  IntRect get rectAdjusted =>
      IntRect.fromLTWH(locationAdjusted.x, locationAdjusted.y, cols, rows);

  /// Cached number of enclosures found (set by ArtifactRegionExt).
  int? cachedEnclosures;

  /// Cached vertical left line detection (set by ArtifactAnalysisExt).
  bool? cachedVerticalLineLeft;

  /// Cached vertical right line detection (set by ArtifactAnalysisExt).
  bool? cachedVerticalLineRight;

  /// Area size of the matrix
  int get area => cols * rows;

  /// rect setting helper
  void setBothLocation(final IntOffset location) {
    locationFound = location;
    locationAdjusted = location;
  }

  /// Calculates the aspect ratio of the content within the matrix.
  ///
  /// Returns the height-to-width ratio of the bounding box containing all true cells.
  double aspectRatioOfContent() {
    final IntRect rect = getContentRect();
    return rect.height / rect.width; // Aspect ratio
  }

  /// Retrieves the value of a cell at the specified coordinates.
  ///
  /// Returns false if the coordinates are out of bounds.
  bool cellGet(final int x, final int y) {
    assert(_isValidXY(x, y) == true);
    return _matrix[y * cols + x] == _pixelOnValue;
  }

  /// Sets the value of a cell at the specified coordinates.
  ///
  /// Does nothing if the coordinates are out of bounds.
  void cellSet(final int x, final int y, bool value) {
    assert(_isValidXY(x, y) == true);
    _matrix[y * cols + x] = value ? _pixelOnValue : _pixelOffValue;
  }

  /// Determines if this artifact contains content that can be discarded.
  ///
  /// An artifact is considered discardable if it is very small
  /// (area ≤ [_maxDiscardableArea])
  /// or if it is classified as a line.
  ///
  /// Returns true if the artifact can be discarded, false otherwise.
  bool discardableContent() {
    return area <= _maxDiscardableArea || isConsideredLine();
  }

  /// Calculates the bounding rectangle of the content in the matrix.
  ///
  /// This method finds the smallest rectangle that encompasses all true cells
  /// in the matrix. It's useful for determining the area of the matrix that
  /// contains actual content.
  ///
  /// Returns:
  /// A IntRect object representing the bounding rectangle of the content.
  /// The rectangle is defined by its left, top, right, and bottom coordinates.
  ///
  /// If the matrix is empty or contains no true cells, it returns Rect.zero.
  ///
  /// Note:
  /// - The returned IntRect uses double values for coordinates to be compatible
  ///   with Flutter's IntRect class.
  /// - The right and bottom coordinates are exclusive (i.e., they point to
  ///   the cell just after the last true cell in each direction).
  IntRect getContentRect() {
    int minX = cols;
    int maxX = _noContentSentinel;
    int minY = rows;
    int maxY = _noContentSentinel;

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        if (cellGet(x, y)) {
          minX = min(minX, x);
          maxX = max(maxX, x);
          minY = min(minY, y);
          maxY = max(maxY, y);
        }
      }
    }

    // If no content found, return Rect.zero
    if (maxX == _noContentSentinel || maxY == _noContentSentinel) {
      return IntRect();
    } else {
      return IntRect.fromLTRB(minX, minY, (maxX + 1), (maxY + 1));
    }
  }

  /// Determines if the current Artifact is considered a line based on its aspect ratio.
  ///
  /// This method calculates the aspect ratio of the Artifact's content and checks if it falls
  /// within a specific range to determine if it should be considered a line.
  ///
  /// Returns:
  ///   * true if the aspect ratio is less than [_lineAspectRatioMin] or greater
  ///     than [_lineAspectRatioMax], indicating that the Artifact is likely
  ///     representing a line.
  ///   * false otherwise, suggesting the Artifact is not representing a line.
  ///
  /// The aspect ratio is calculated by the aspectRatioOfContent() method as
  /// height divided by width. Therefore:
  ///   * A very small aspect ratio indicates a tall, narrow Artifact.
  ///   * A very large aspect ratio indicates a wide, short Artifact.
  /// Both of these cases are considered to be line-like in this context.
  ///
  /// This method is useful in image processing or OCR tasks where distinguishing
  /// between line-like structures and other shapes is important.
  bool isConsideredLine() {
    final double ar = aspectRatioOfContent();
    return ar < _lineAspectRatioMin || ar > _lineAspectRatioMax;
  }

  /// The grid contains one or more True values
  bool get isEmpty => getContentRect().isEmpty;

  /// All entries in the grid are false
  bool get isNotEmpty => !isEmpty;

  /// smaller (~40%) in height artifacts will be considered punctuation
  bool isPunctuation() {
    // Calculate the height of the content
    final IntRect rect = getContentRect();

    // If there's no content, it's not punctuation
    if (rect.isEmpty) {
      return false;
    }

    // Check if the content height is less than 40% of the total height
    return rect.height < (rows * _punctuationHeightRatio);
  }

  /// Ensure that x & y are in the boundary of the grid
  bool _isValidXY(final int x, final int y) {
    return (x >= 0 && x < cols) && (y >= 0 && y < rows);
  }

  /// Sets the grid from a flat [Uint8List] and column count.
  ///
  /// If [grid] is empty, the artifact is cleared.
  void setGrid(final Uint8List grid, final int cols) {
    if (grid.isEmpty) {
      clear();
      return;
    }
    this.cols = cols;

    // Create a deep copy of the grid
    _matrix = Uint8List.fromList(grid);
  }

  /// Sets the grid of the Artifact object from a 2D list of boolean values.
  ///
  /// This method takes a 2D list of boolean values representing the grid and
  /// converts it to the internal Uint8List representation.
  ///
  /// Parameters:
  ///   [input] (```List<List<bool>>```): The 2D list of boolean values representing the grid.
  ///
  /// If the input grid is empty or has no rows, the Artifact is cleared.
  void setGridFromBools(final List<List<bool>> input) {
    if (input.isEmpty || input[0].isEmpty) {
      clear();
      return;
    }
    cols = input[0].length;

    // Create a new Uint8List to store the flattened grid data
    _matrix = Uint8List(input.length * cols);

    // Copy the input data into the flattened array
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        cellSet(x, y, input[y][x]);
      }
    }
  }

  /// Sorts a list of Artifact objects based on their vertical and horizontal positions.
  ///
  /// This method first compares the vertical center positions of artifacts.
  /// If two artifacts are approximately on the same line (within
  /// [_sameLineVerticalThreshold] pixels vertically),
  /// it sorts them from left to right based on their horizontal position.
  /// Otherwise, it sorts them from top to bottom.
  ///
  /// Parameters:
  ///   [list]: The list of Artifact objects to sort.
  static void sortMatrices(List<Artifact> list) {
    list.sort((Artifact a, Artifact b) {
      final aCenterY = a.rectFound.top + a.rectFound.height / _centerDivisor;
      final bCenterY = b.rectFound.top + b.rectFound.height / _centerDivisor;
      if ((aCenterY - bCenterY).abs() < _sameLineVerticalThreshold) {
        return a.rectFound.left.compareTo(b.rectFound.left);
      }
      return aCenterY.compareTo(bCenterY);
    });
  }

  /// Sorts a list of IntRect objects based on their vertical and horizontal positions.
  ///
  /// This method first compares the vertical center positions of rectangles.
  /// If two rectangles are approximately on the same line (within the specified threshold),
  /// it sorts them from left to right based on their horizontal position.
  /// Otherwise, it sorts them from top to bottom.
  ///
  /// Parameters:
  ///   [list]: The list of IntRect objects to sort.
  ///   [threshold]: The maximum vertical distance (in pixels) for rectangles to be
  ///                considered on the same line. Defaults to
  ///                [_defaultRectangleSortThreshold].
  static void sortRectangles(
    List<IntRect> list, {
    double threshold = _defaultRectangleSortThreshold,
  }) {
    list.sort((a, b) {
      // If the vertical difference is within the threshold, treat them as the same row
      if ((a.center.y - b.center.y).abs() <= threshold) {
        return a.center.x.compareTo(
          b.center.x,
        ); // Sort by X-axis if on the same line
      }
      return a.center.y.compareTo(b.center.y); // Otherwise, sort by Y-axis
    });
  }

  /// Applies an offset to the location of a list of matrices.
  static void offsetArtifacts(
    final List<Artifact> matrices,
    final int x,
    final int y,
  ) {
    for (final Artifact matrix in matrices) {
      matrix.locationFound = matrix.locationFound.translate(x, y);
    }
  }

  /// Creates a [Artifact] from a [Image].
  static Future<Artifact> artifactFromImage(final Image image) async {
    final Uint8List uint8List = await imageToUint8List(image);
    return Artifact.fromUint8List(uint8List, image.width);
  }

  /// Copies the contents of a source Artifact into a target Artifact, with an optional offset.
  static void copyArtifactGrid(
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

  /// Calculates the normalized Hamming distance between two matrices.
  ///
  /// Returns a double value between 0 and 1, where:
  /// - 1.0 indicates perfect similarity (no differences)
  /// - 0.0 indicates maximum dissimilarity
  static double hammingDistancePercentageOfTwoArtifacts(
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
    }

    return matchingPixels / totalPixels;
  }
}

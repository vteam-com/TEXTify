import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:textify/utilities.dart';

/// Represents a 2D grid of boolean values, primarily used for image processing
/// and pattern recognition tasks.
///
/// This class provides various ways to create, manipulate, and analyze boolean matrices,
/// including methods for resizing, comparing, and extracting information from the grid.
class Artifact {
  /// Main constructor
  Artifact(this.cols, int rows) {
    _matrix = Uint8List(rows * cols);
  }

  /// Creates a new [Artifact] instance from an existing [Artifact].
  ///
  /// This factory method creates a new [Artifact] instance based on the provided [value] matrix.
  /// It copies the grid data and the rectangle properties from the input matrix.
  ///
  /// Parameters:
  /// - [value]: The source [Artifact] instance to copy from.
  ///
  /// Returns:
  /// A new [Artifact] instance with the same grid data and rectangle as the input matrix.
  ///
  /// Note: This method creates a shallow copy of the grid data. If deep copying of the data
  /// is required, consider implementing a separate deep copy method.
  ///
  /// Example:
  /// ```dart
  /// Matrix original = Matrix(/* ... */);
  /// Matrix copy = Matrix.fromMatrix(original);
  /// ```
  factory Artifact.fromMatrix(final Artifact value) {
    final Artifact artifact = Artifact(0, 0);
    artifact.setGrid(value._matrix, value.cols);
    artifact.locationFound = value.locationFound;
    artifact.locationAdjusted = value.locationAdjusted;
    return artifact;
  }

  /// Creates a Matrix from an ASCII representation.
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

  /// Creates a Matrix from a multi-line ASCII string representation.
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

  /// Creates a Matrix from an existing 2D boolean list.
  ///
  /// [input] A 2D list of boolean values.
  factory Artifact.fromBoolMatrix(final List<List<bool>> input) {
    final Artifact artifact = Artifact(0, 0);
    artifact.setGridFromBools(input);
    return artifact;
  }

  /// Creates a Matrix from JSON data.
  ///
  /// [json] A map containing 'rows', 'cols', and 'data' keys.
  factory Artifact.fromJson(final Map<String, dynamic> json) {
    // determine the mandatory cols/width of the matrix
    final int cols = (json['cols'] as int?) ?? 0;
    final Artifact artifact = Artifact(cols, 0);
    artifact.font = json['font'] ?? '';
    artifact._matrix = Uint8List.fromList(
      (json['data'] as List<dynamic>).expand((final dynamic row) {
        return row.toString().split('').map((cell) => cell == '#' ? 1 : 0);
      }).toList(),
    );
    return artifact;
  }

  /// Creates a Matrix from a Uint8List, typically used for image data.
  ///
  /// [pixels] A Uint8List representing pixel data.
  /// [width] The width of the image.
  factory Artifact.fromUint8List(
    final Uint8List pixels,
    final int width,
  ) {
    return Artifact.fromFlatListOfBool(
      [
        for (int i = 0; i < pixels.length; i += 4) pixels[i] == 0,
      ],
      width,
    );
  }

  /// Creates a Matrix from a flat list of boolean values.
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
  String characterMatched = '';

  /// Tag the artifact as needing more attention during inspection
  bool needsInspection = false;

  /// Indicates whether this artifact was created as part of a splitting operation
  bool wasPartOfSplit = false;

  /// Empty the content
  void clear() {
    this.cols = 0;
    this._matrix = Uint8List(0);
  }

  /// Converts the matrix to a text representation.
  ///
  /// This method creates a string representation of the matrix where each true cell
  /// is represented by the specified character.
  ///
  /// Parameters:
  /// - [onChar]: The character to use for representing true cells. Defaults to '#'.
  /// - [forCode]: Whether the output is intended for code representation. Defaults to false.
  ///
  /// Returns a formatted string representation of the matrix.
  String toText({
    final String onChar = '#',
    final bool forCode = false,
  }) {
    return this.gridToString(
      forCode: forCode,
      onChar: onChar,
    );
  }

  /// Prints the grid to the debug console.
  ///
  /// This method is useful for debugging purposes, allowing visual inspection
  /// of the matrix structure in the console output.
  void debugPrintGrid() {
    debugPrint('${this.toText()}\n');
  }

  /// Merges the current artifact with another artifact.
  ///
  /// This method combines the current artifact with the provided artifact,
  /// creating a new, larger artifact that encompasses both.
  ///
  /// Parameters:
  /// - [toMerge]: The Artifact to be merged with the current artifact.
  ///
  /// The merging process involves:
  /// 1. Creating a new rectangle that encompasses both artifacts.
  /// 2. Creating a new matrix (grid) large enough to contain both artifacts' data.
  /// 3. Copying the data from both artifacts into the new matrix.
  /// 4. Updating the current artifact's matrix and rectangle to reflect the merged state.
  ///
  /// Note: This method modifies the current artifact in-place.
  void mergeArtifact(final Artifact toMerge) {
    // Create a new rectangle that encompasses both artifacts
    final IntRect newRect = IntRect.fromLTRB(
      min(this.rectFound.left, toMerge.rectFound.left),
      min(this.rectFound.top, toMerge.rectFound.top),
      max(this.rectFound.right, toMerge.rectFound.right),
      max(this.rectFound.bottom, toMerge.rectFound.bottom),
    );

    // Create a new grid that can fit both artifacts
    final Artifact newGrid = Artifact(newRect.width, newRect.height);

    // Copy both grids onto the new grid with correct offsets
    copyArtifactGrid(
      this,
      newGrid,
      (this.rectFound.left - newRect.left),
      (this.rectFound.top - newRect.top),
    );

    copyArtifactGrid(
      toMerge,
      newGrid,
      (toMerge.rectFound.left - newRect.left),
      (toMerge.rectFound.top - newRect.top),
    );

    // Update this artifact with the merged data
    this.setGrid(newGrid._matrix, newGrid.cols);
  }

  /// Returns a string representation of this artifact.
  ///
  /// The string includes information about the matched character, position,
  /// dimensions, emptiness status, enclosures, and vertical line detection.
  ///
  /// Returns a formatted string with artifact details.
  @override
  String toString() {
    return '"$characterMatched" left:${locationFound.x} top:${locationFound.y} CW:${rectFound.width} CH:${rectFound.height} isEmpty:$isEmpty E:$enclosures LL:$verticalLineLeft LR:$verticalLineRight';
  }

  /// Returns the horizontal histogram of the matrix.
  ///
  /// The histogram represents the number of `true` (or inked) cells
  /// in each column of the matrix. The result is a list where each
  /// index corresponds to a column, and the value at that index
  /// represents the count of `true` values in that column.
  List<int> getHistogramHorizontal() {
    final List<int> histogram = List.filled(this.cols, 0);
    for (int x = 0; x < this.cols; x++) {
      for (int y = 0; y < this.rows; y++) {
        if (this.cellGet(x, y)) {
          histogram[x]++;
        }
      }
    }
    return histogram;
  }

  /// Font this matrix template is based on
  String font = '';

  /// The number of columns in the matrix.
  int cols = 0;

  /// The number of rows in the matrix.
  int get rows => _matrix.isEmpty ? 0 : _matrix.length ~/ this.cols;

  /// The 2D list representing the boolean grid.
  /// Each outer list represents a row, and each inner list represents a column.
  /// _data[row][column] gives the boolean value at that position.
  Uint8List _matrix = Uint8List(0);

  /// The 2D list representing the boolean grid.
  Uint8List get matrix => _matrix;

  /// the location of this matrix.
  IntOffset locationFound = IntOffset();

  /// the rectangle location of this matrix.
  IntRect get rectFound => IntRect.fromLTWH(
        locationFound.x,
        locationFound.y,
        cols,
        rows,
      );

  /// the location moved to
  IntOffset locationAdjusted = IntOffset();

  /// the rectangle location of this matrix.
  IntRect get rectAdjusted => IntRect.fromLTWH(
        locationAdjusted.x,
        locationAdjusted.y,
        cols,
        rows,
      );

  /// The number of enclosure found
  int _enclosures = -1;

  /// The number of vertical left lines found
  bool? _verticalLineLeft;

  /// The number of vertical right lines found
  bool? _verticalLineRight;

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
    return _matrix[y * cols + x] == 1;
  }

  /// Sets the value of a cell at the specified coordinates.
  ///
  /// Does nothing if the coordinates are out of bounds.
  void cellSet(final int x, final int y, bool value) {
    assert(_isValidXY(x, y) == true);
    _matrix[y * cols + x] = value ? 1 : 0;
  }

  /// Determines if this artifact contains content that can be discarded.
  ///
  /// An artifact is considered discardable if it is very small (area ≤ 2)
  /// or if it is classified as a line.
  ///
  /// Returns true if the artifact can be discarded, false otherwise.
  bool discardableContent() {
    return this.area <= 2 || isConsideredLine();
  }

  /// Returns the vertical histogram of the matrix.
  ///
  /// The histogram represents the number of `true` (or inked) cells
  /// in each row of the matrix. The result is a list where each
  /// index corresponds to a row, and the value at that index
  /// represents the count of `true` values in that row.
  List<int> getHistogramVertical() {
    final List<int> histogram = List.filled(this.rows, 0);
    for (int y = 0; y < this.rows; y++) {
      for (int x = 0; x < this.cols; x++) {
        if (this.cellGet(x, y)) {
          histogram[y]++;
        }
      }
    }
    return histogram;
  }

  /// Trims the matrix by removing empty rows and columns from all sides.
  ///
  /// This method removes rows and columns that contain only false values from
  /// the edges of the matrix, effectively trimming it to the smallest possible
  /// size that contains all true values.
  ///
  /// Returns:
  /// A new Matrix object that is a trimmed version of the original. If the
  /// original matrix is empty or contains only false values, it returns an
  /// empty Matrix.
  ///
  /// Note: This method does not modify the original matrix but returns a new one.
  Artifact trim() {
    if (isEmpty) {
      return Artifact(0, 0);
    }
    // Find the boundaries of the content
    int topRow = 0;
    int bottomRow = rows - 1;
    int leftCol = 0;
    int rightCol = cols - 1;

    // Find top row with content
    while (topRow < rows) {
      bool hasContent = false;
      for (int x = 0; x < cols; x++) {
        if (cellGet(x, topRow)) {
          hasContent = true;
          break;
        }
      }
      if (hasContent) {
        break;
      }
      topRow++;
    }

    // Find bottom row with content
    while (bottomRow > topRow) {
      bool hasContent = false;
      for (int x = 0; x < cols; x++) {
        if (cellGet(x, bottomRow)) {
          hasContent = true;
          break;
        }
      }
      if (hasContent) {
        break;
      }
      bottomRow--;
    }

    // Find left column with content
    outer:
    while (leftCol < cols) {
      for (int y = topRow; y <= bottomRow; y++) {
        if (cellGet(leftCol, y)) {
          break outer;
        }
      }
      leftCol++;
    }

    // Find right column with content
    outer:
    while (rightCol > leftCol) {
      for (int y = topRow; y <= bottomRow; y++) {
        if (cellGet(rightCol, y)) {
          break outer;
        }
      }
      rightCol--;
    }

    // Crop the grid
    final Artifact result = Artifact(
      rightCol - leftCol + 1,
      bottomRow - topRow + 1,
    );
    for (int y = topRow; y <= bottomRow; y++) {
      for (int x = leftCol; x <= rightCol; x++) {
        result.cellSet(x - leftCol, y - topRow, cellGet(x, y));
      }
    }
    return result;
  }

  /// Creates a new Artifact with the specified desired width and height, by resizing the current Artifact.
  ///
  /// If the current Artifact is punctuation, it will not be cropped and will be centered in the new Artifact.
  /// Otherwise, the current Artifact will be trimmed and then wrapped with false values before being resized.
  ///
  /// Parameters:
  /// - `desiredWidth`: The desired width of the new Artifact.
  /// - `desiredHeight`: The desired height of the new Artifact.
  ///
  /// Returns:
  /// A new Artifact with the specified dimensions, containing a resized version of the original Artifact's content.
  Artifact createNormalizeMatrix(
    final int desiredWidth,
    final int desiredHeight,
  ) {
    // help resizing by ensuring there's a border
    if (isPunctuation()) {
      // do not crop and center
      return _createWrapGridWithFalse()._createResizedGrid(
        desiredWidth,
        desiredHeight,
      );
    } else {
      // Resize
      return trim()._createWrapGridWithFalse()._createResizedGrid(
            desiredWidth,
            desiredHeight,
          );
    }
  }

  /// Creates a resized version of the current matrix.
  ///
  /// This method resizes the matrix to the specified target dimensions using
  /// different strategies for upscaling and downscaling.
  ///
  /// Parameters:
  /// - [targetWidth]: The desired width of the resized matrix.
  /// - [targetHeight]: The desired height of the resized matrix.
  ///
  /// Returns:
  /// A new Matrix object with the specified dimensions, containing a resized
  /// version of the original matrix's content.
  ///
  /// Resizing strategy:
  /// - For upscaling (target size larger than original), it uses nearest-neighbor interpolation.
  /// - For downscaling (target size smaller than original), it averages the values in each sub-grid.
  Artifact _createResizedGrid(final int targetWidth, final int targetHeight) {
    // Initialize the resized grid
    final Artifact resizedGrid = Artifact(targetWidth, targetHeight);

    // Calculate the scale factors
    final double xScale = cols / targetWidth;
    final double yScale = rows / targetHeight;

    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        // Coordinates in the original grid
        final double srcX = x * xScale;
        final double srcY = y * yScale;

        if (targetWidth > cols || targetHeight > rows) {
          // UpScaling: Use nearest-neighbor interpolation
          final int srcXInt = srcX.floor();
          final int srcYInt = srcY.floor();
          resizedGrid.cellSet(x, y, cellGet(srcXInt, srcYInt));
        } else {
          // DownScaling: Check for any black pixel in the sub-grid
          final int startX = srcX.floor();
          final int endX = (srcX + xScale).ceil();
          final int startY = srcY.floor();
          final int endY = (srcY + yScale).ceil();

          bool hasBlackPixel = false;

          for (int sy = startY; sy < endY && sy < rows; sy++) {
            for (int sx = startX; sx < endX && sx < cols; sx++) {
              if (cellGet(sx, sy)) {
                hasBlackPixel = true;
                break;
              }
            }
            if (hasBlackPixel) {
              break;
            }
          }
          // Set the resized grid value based on the presence of any black pixel
          resizedGrid.cellSet(x, y, hasBlackPixel);
        }
      }
    }
    return resizedGrid;
  }

  /// Adds padding to the top and bottom of the matrix.
  ///
  /// This method inserts blank lines at the top and bottom of the matrix data,
  /// effectively adding padding to the matrix.
  ///
  /// Parameters:
  /// - [paddingTop]: The number of blank lines to add at the top of the matrix.
  /// - [paddingBottom]: The number of blank lines to add at the bottom of the matrix.
  ///
  /// The method modifies the matrix in place by:
  /// 1. Creating blank lines (rows filled with `false` values).
  /// 2. Inserting the specified number of blank lines at the top of the matrix.
  /// 3. Appending the specified number of blank lines at the bottom of the matrix.
  /// 4. Updating the total number of rows in the matrix.
  void padTopBottom({
    required final int paddingTop,
    required final int paddingBottom,
  }) {
    final int newRows = this.rows + paddingTop + paddingBottom;
    final Uint8List newMatrix = Uint8List(newRows * this.cols);

    // Copy old matrix into the new padded matrix
    for (int y = 0; y < this.rows; y++) {
      for (int x = 0; x < this.cols; x++) {
        newMatrix[(y + paddingTop) * this.cols + x] =
            this._matrix[y * this.cols + x];
      }
    }

    // Replace old matrix
    this._matrix = newMatrix;
  }

  /// Creates a new Matrix with a false border wrapping around the original matrix.
  ///
  /// This function generates a new Matrix that is larger than the original by adding
  /// a border of 'false' values around all sides. If the original matrix is empty,
  /// it returns a predefined 3x2 matrix of 'false' values.
  ///
  /// The process:
  /// 1. If the original matrix is empty, return a predefined 3x2 matrix of 'false' values.
  /// 2. Create a new matrix with dimensions increased by 2 in both rows and columns,
  ///    initialized with 'false' values.
  /// 3. Copy the original matrix data into the center of the new matrix, leaving
  ///    the outer border as 'false'.
  ///
  /// Returns:
  /// - If the original matrix is empty: A new 3x2 Matrix filled with 'false' values.
  /// - Otherwise: A new Matrix with dimensions (rows + 2) x (cols + 2), where the
  ///   original matrix data is centered and surrounded by a border of 'false' values.
  ///
  /// This function is useful for operations that require considering the edges of a matrix,
  /// such as cellular automata or image processing algorithms.
  Artifact _createWrapGridWithFalse() {
    if (isEmpty) {
      return Artifact.fromBoolMatrix([
        [false, false],
        [false, false],
        [false, false],
      ]);
    }

    // Create a new grid with increased dimensions
    final Artifact newGrid = Artifact(cols + 2, rows + 2);

    // Copy the original grid into the center of the new grid
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        newGrid.cellSet(x + 1, y + 1, cellGet(x, y));
      }
    }

    return newGrid;
  }

  /// Gets the number of enclosed regions in the matrix.
  ///
  /// An enclosed region is a contiguous area of false cells completely
  /// surrounded by true cells. This property is useful for character recognition,
  /// as different characters have different numbers of enclosed regions
  /// (e.g., 'O' has one, 'B' has two).
  ///
  /// Returns the number of enclosed regions in the matrix.
  int get enclosures {
    if (_enclosures < 0) {
      _enclosures = _countEnclosedRegion(this);
    }
    return _enclosures;
  }

  /// Extracts a sub-grid from a larger binary image matrix.
  ///
  /// This static method creates a new Matrix object representing a portion of
  /// the input binary image, as specified by the given rectangle.
  ///
  /// Parameters:
  /// - [matrix]: The source Matrix from which to extract the sub-grid.
  /// - [rect]: A IntRect object specifying the region to extract. The rectangle's
  ///   coordinates are relative to the top-left corner of the binaryImage.
  ///
  /// Returns:
  /// A new Matrix object containing the extracted sub-grid.
  ///
  /// Note:
  /// - If the specified rectangle extends beyond the boundaries of the source
  ///   image, the out-of-bounds areas in the resulting sub-grid will be false.
  /// - The method uses integer coordinates, so any fractional values in the
  ///   rect will be truncated.
  Artifact extractSubGrid({
    required final IntRect rect,
  }) {
    final int startX = rect.left.toInt();
    final int startY = rect.top.toInt();
    final int subImageWidth = rect.width.toInt();
    final int subImageHeight = rect.height.toInt();

    final Artifact subImagePixels = Artifact(subImageWidth, subImageHeight);

    for (int x = 0; x < subImageWidth; x++) {
      for (int y = 0; y < subImageHeight; y++) {
        final int sourceX = startX + x;
        final int sourceY = startY + y;

        if (sourceX < this.cols && sourceY < this.rows) {
          subImagePixels.cellSet(x, y, this.cellGet(sourceX, sourceY));
        }
      }
    }

    subImagePixels.locationFound = rect.shift(this.rectFound.topLeft).topLeft;
    subImagePixels.locationAdjusted =
        rect.shift(this.rectAdjusted.topLeft).topLeft;

    return subImagePixels;
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
    int maxX = -1;
    int minY = rows;
    int maxY = -1;

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
    if (maxX == -1 || maxY == -1) {
      return IntRect();
    } else {
      return IntRect.fromLTRB(
        minX,
        minY,
        (maxX + 1),
        (maxY + 1),
      );
    }
  }

  /// Converts the matrix to a string representation.
  ///
  /// This method creates a string representation of the matrix, with options
  /// to format it for code or for display.
  ///
  /// Parameters:
  /// - [forCode]: If true, formats the output as a Dart string literal.
  ///              Default is false.
  /// - [onChar]: The character to represent true cells. Default is '#'.
  /// - [offChar]: The character to represent false cells. Default is '.'.
  ///
  /// Returns:
  /// A string representation of the matrix. If [forCode] is true, the string
  /// is formatted as a multi-line Dart string literal. Otherwise, it's a
  /// simple string with newline characters separating rows.
  ///
  ///
  /// Note: This method uses [gridToStrings] internally to generate the list
  /// of strings representing each row of the matrix.
  String gridToString({
    final bool forCode = false,
    final String onChar = '#',
    final String offChar = '.',
  }) {
    final List<String> list = gridToStrings(onChar: onChar, offChar: offChar);
    return forCode ? '"${list.join('",\n"')}"' : list.join('\n');
  }

  /// Converts the matrix to a list of strings.
  ///
  /// This method creates a list where each string represents a row in the matrix.
  ///
  /// Parameters:
  /// - [onChar]: The character to represent true cells. Default is '#'.
  /// - [offChar]: The character to represent false cells. Default is '.'.
  ///
  /// Returns:
  /// A ```List<String>``` where each string represents a row in the matrix.
  ///
  /// Example:
  /// ```dart
  /// // ["#.#", ".#.", "#.#"]
  /// ```
  List<String> gridToStrings({
    final String onChar = '#',
    final String offChar = '.',
  }) {
    final List<String> result = [];

    for (int row = 0; row < rows; row++) {
      String rowString = '';
      for (int col = 0; col < cols; col++) {
        rowString += cellGet(col, row) ? onChar : offChar;
      }

      result.add(rowString);
    }

    return result;
  }

  /// Determines if the current Matrix is considered a line based on its aspect ratio.
  ///
  /// This method calculates the aspect ratio of the Matrix's content and checks if it falls
  /// within a specific range to determine if it should be considered a line.
  ///
  /// Returns:
  ///   * true if the aspect ratio is less than 0.25 or greater than 50,
  ///     indicating that the Matrix is likely representing a line.
  ///   * false otherwise, suggesting the Matrix is not representing a line.
  ///
  /// The aspect ratio is calculated by the aspectRatioOfContent() method, which is
  /// assumed to return width divided by height of the Matrix's content. Therefore:
  ///   * A very small aspect ratio (< 0.25) indicates a tall, narrow Matrix.
  ///   * A very large aspect ratio (> 50) indicates a wide, short Matrix.
  /// Both of these cases are considered to be line-like in this context.
  ///
  /// This method is useful in image processing or OCR tasks where distinguishing
  /// between line-like structures and other shapes is important.
  bool isConsideredLine() {
    final double ar = aspectRatioOfContent();
    return ar < 0.09 || ar > 50;
  }

  /// The grid contains one or more True values
  bool get isEmpty => getContentRect().isEmpty;

  /// All entries in the grid are false
  bool get isNotEmpty => !isEmpty;

  /// smaller (~30%) in height artifacts will be considered punctuation
  bool isPunctuation() {
    // Calculate the height of the content
    final IntRect rect = getContentRect();

    // If there's no content, it's not punctuation
    if (rect.isEmpty) {
      return false;
    }

    // Check if the content height is less than 40% of the total height
    return rect.height < (rows * 0.40);
  }

  /// Ensure that x & y are in the boundary of the grid
  bool _isValidXY(final int x, final int y) {
    return (x >= 0 && x < cols) && (y >= 0 && y < rows);
  }

  /// Sets the grid of the Matrix object.
  ///
  /// This method takes a 2D list of boolean values representing the grid of the Matrix.
  /// It ensures that all rows have the same length, and creates a deep copy of the
  /// grid to store in the Matrix's internal `_data` field.
  ///
  /// If the input grid is empty or has no rows, the Matrix's `rows` and `cols` fields
  /// are set to 0, and the `_data` field is set to an empty list.
  ///
  /// Parameters:
  ///   [grid] (```Uint8List```): The 2D list of boolean values representing the grid.
  void setGrid(final Uint8List grid, final int cols) {
    if (grid.isEmpty) {
      this.clear();
      return;
    }
    this.cols = cols;

    // Create a deep copy of the grid
    _matrix = Uint8List.fromList(grid);
  }

  /// Sets the grid of the Matrix object from a 2D list of boolean values.
  ///
  /// This method takes a 2D list of boolean values representing the grid and
  /// converts it to the internal Uint8List representation.
  ///
  /// Parameters:
  ///   [input] (```List<List<bool>>```): The 2D list of boolean values representing the grid.
  ///
  /// If the input grid is empty or has no rows, the Matrix is cleared.
  void setGridFromBools(final List<List<bool>> input) {
    if (input.isEmpty || input[0].isEmpty) {
      this.clear();
      return;
    }
    cols = input[0].length;

    // Create a new Uint8List to store the flattened grid data
    _matrix = Uint8List(input.length * cols);

    // Copy the input data into the flattened array
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        this.cellSet(x, y, input[y][x]);
      }
    }
  }

  /// Converts the Matrix object to a JSON-serializable Map.
  ///
  /// This method creates a Map representation of the Matrix object that can be
  /// easily serialized to JSON. The resulting Map contains the following keys:
  ///
  /// - 'font': The font used in the Matrix (type depends on how 'font' is defined in the class).
  /// - 'rows': The number of rows in the Matrix.
  /// - 'cols': The number of columns in the Matrix.
  /// - 'data': A List of Strings, where each String represents a row in the Matrix.
  ///           In these Strings, '#' represents true (or filled) cells, and '.'
  ///           represents false (or empty) cells.
  ///
  /// The 'data' field is created by transforming the 2D boolean array into a more
  /// compact string representation, where each row is converted to a string of
  /// '#' and '.' characters.
  ///
  /// Returns:
  ///   A ```Map<String, dynamic>``` that can be serialized to JSON, representing the
  ///   current state of the Matrix object.
  ///
  Map<String, dynamic> toJson() {
    return {
      'font': font,
      'rows': rows,
      'cols': cols,
      'data': _matrix.map((row) {
        return List.generate(rows, (y) {
          return List.generate(cols, (x) => cellGet(x, y) ? '#' : '.').join();
        });
      }).toList(),
    };
  }

  /// Determines if there's a vertical line on the left side of the matrix.
  ///
  /// This getter lazily evaluates and caches the result of checking for a vertical
  /// line on the left side of the matrix. It uses the [_hasVerticalLineLeft] method
  /// to perform the actual check.
  ///
  /// Returns:
  ///   A boolean value:
  ///   - true if a vertical line is present on the left side
  ///   - false otherwise
  ///
  /// The result is cached after the first call for efficiency in subsequent accesses.
  bool get verticalLineLeft {
    _verticalLineLeft ??= _hasVerticalLineLeft(this);
    return _verticalLineLeft!;
  }

  /// Determines if there's a vertical line on the right side of the matrix.
  ///
  /// This getter lazily evaluates and caches the result of checking for a vertical
  /// line on the right side of the matrix. It uses the [_hasVerticalLineRight] method
  /// to perform the actual check.
  ///
  /// Returns:
  ///   A boolean value:
  ///   - true if a vertical line is present on the right side
  ///   - false otherwise
  ///
  /// The result is cached after the first call for efficiency in subsequent accesses.
  bool get verticalLineRight {
    _verticalLineRight ??= _hasVerticalLineRight(this);
    return _verticalLineRight!;
  }

  /// Counts the number of enclosed regions in a given grid.
  ///
  /// This function analyzes a binary grid represented by [Artifact] to identify and count
  /// enclosed regions that meet specific criteria.
  ///
  /// Parameters:
  /// - [grid]: A [Artifact] object representing the binary grid to analyze.
  ///
  /// Returns:
  /// An integer representing the count of enclosed regions that meet the criteria.
  ///
  /// Algorithm:
  /// 1. Initializes a 'visited' matrix to keep track of explored cells.
  /// 2. Iterates through each cell in the grid.
  /// 3. For each unvisited 'false' cell (representing a potential region):
  ///    a. Explores the connected region using [_exploreRegion].
  ///    b. If the region size is at least [minRegionSize] (3 in this case) and
  ///       it's confirmed as enclosed by [_isEnclosedRegion], increments the loop count.
  ///
  /// Note:
  /// - The function assumes the existence of helper methods [_exploreRegion] and [_isEnclosedRegion].
  /// - A region must have at least 3 cells to be considered a loop.
  /// - The function uses a depth-first search approach to explore regions.
  ///
  /// Time Complexity: O(rows * cols), where each cell is visited at most once.
  /// Space Complexity: O(rows * cols) for the 'visited' matrix.
  static int _countEnclosedRegion(final Artifact grid) {
    final int rows = grid.rows;
    final int cols = grid.cols;

    final Artifact visited = Artifact(cols, rows);

    int loopCount = 0;
    int minRegionSize = 3; // Minimum size for a region to be considered a loop

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        if (!grid.cellGet(x, y) && !visited.cellGet(x, y)) {
          int regionSize = _exploreRegion(grid, visited, x, y);
          if (regionSize >= minRegionSize &&
              _isEnclosedRegion(grid, x, y, regionSize)) {
            loopCount++;
          }
        }
      }
    }

    return loopCount;
  }

  /// Sorts a list of Artifact objects based on their vertical and horizontal positions.
  ///
  /// This method first compares the vertical center positions of artifacts.
  /// If two artifacts are approximately on the same line (within 10 pixels vertically),
  /// it sorts them from left to right based on their horizontal position.
  /// Otherwise, it sorts them from top to bottom.
  ///
  /// Parameters:
  ///   [list]: The list of Artifact objects to sort.
  static void sortMatrices(List<Artifact> list) {
    list.sort((Artifact a, Artifact b) {
      final aCenterY = a.rectFound.top + a.rectFound.height / 2;
      final bCenterY = b.rectFound.top + b.rectFound.height / 2;
      if ((aCenterY - bCenterY).abs() < 10) {
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
  ///                considered on the same line. Defaults to 5.0.
  static void sortRectangles(List<IntRect> list, {double threshold = 5.0}) {
    list.sort((a, b) {
      // If the vertical difference is within the threshold, treat them as the same row
      if ((a.center.y - b.center.y).abs() <= threshold) {
        return a.center.x
            .compareTo(b.center.x); // Sort by X-axis if on the same line
      }
      return a.center.y.compareTo(b.center.y); // Otherwise, sort by Y-axis
    });
  }

  /// Explores a connected region in a grid starting from a given point.
  ///
  /// This function uses a breadth-first search algorithm to explore a region
  /// of connected cells in a grid, starting from the specified coordinates.
  ///
  /// Parameters:
  /// - [grid]: A Matrix representing the grid to explore.
  ///   Assumed to contain boolean values where false represents an explorable cell.
  /// - [visited]: A Matrix of the same size as [grid] to keep track of visited cells.
  /// - [startX]: The starting X-coordinate for exploration.
  /// - [startY]: The starting Y-coordinate for exploration.
  ///
  /// Returns:
  /// The size of the explored region (number of connected cells).
  ///
  /// Note: This function modifies the [visited] matrix in-place to mark explored cells.
  static int _exploreRegion(
    final Artifact grid,
    final Artifact visited,
    final int startX,
    final int startY,
  ) {
    int rows = grid.rows;
    int cols = grid.cols;
    Queue<List<int>> queue = Queue();
    queue.add([startX, startY]);
    visited.cellSet(startX, startY, true);
    int regionSize = 0;

    // Directions for exploring adjacent cells (up, down, left, right)
    final directions = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];

    while (queue.isNotEmpty) {
      final List<int> current = queue.removeFirst();
      final int x = current[0], y = current[1];
      regionSize++;

      // Explore all adjacent cells
      for (final List<int> dir in directions) {
        final int newX = x + dir[0], newY = y + dir[1];

        // Check if the new coordinates are within bounds and the cell is explorable
        if (newX >= 0 &&
            newX < cols &&
            newY >= 0 &&
            newY < rows &&
            !grid.cellGet(newX, newY) &&
            !visited.cellGet(newX, newY)) {
          queue.add([newX, newY]);
          visited.cellSet(newX, newY, true);
        }
      }
    }

    return regionSize;
  }

  /// Determines if a region in a grid is enclosed.
  ///
  /// This function uses a breadth-first search algorithm to explore a region
  /// starting from the given coordinates and checks if it's enclosed within the grid.
  ///
  /// Parameters:
  /// - [grid]: A Matrix representing the grid.
  ///   Assumed to contain boolean values where false represents an explorable cell.
  /// - [startX]: The starting X-coordinate for exploration.
  /// - [startY]: The starting Y-coordinate for exploration.
  /// - [regionSize]: The size of the region being checked.
  ///
  /// Returns:
  /// A boolean value indicating whether the region is enclosed (true) or not (false).
  ///
  /// A region is considered not enclosed if:
  /// 1. It reaches the edge of the grid during exploration.
  /// 2. Its size is less than 1% of the total grid area (adjustable threshold).
  static bool _isEnclosedRegion(
    final Artifact grid,
    final int startX,
    final int startY,
    final int regionSize,
  ) {
    final int rows = grid.rows;
    final int cols = grid.cols;
    final Queue<List<int>> queue = Queue();
    final Set<String> visited = {};
    queue.add([startX, startY]);
    visited.add('$startX,$startY');
    bool isEnclosed = true;

    // Directions for exploring adjacent cells (up, down, left, right)
    final List<List<int>> directions = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];

    while (queue.isNotEmpty) {
      final List<int> current = queue.removeFirst();
      final int x = current[0], y = current[1];

      for (final List<int> dir in directions) {
        int newX = x + dir[0], newY = y + dir[1];

        // Check if the new coordinates are outside the grid
        if (newX < 0 || newX >= cols || newY < 0 || newY >= rows) {
          isEnclosed = false;
          continue;
        }

        final String key = '$newX,$newY';
        // If the cell is explorable and not visited, add it to the queue
        if (!grid.cellGet(newX, newY) && !visited.contains(key)) {
          queue.add([newX, newY]);
          visited.add(key);
        }
      }
    }

    // Check if the region is too small compared to the grid size
    final int gridArea = rows * cols;
    final double regionPercentage = regionSize / gridArea;
    if (regionPercentage < 0.01) {
      // Adjust this threshold as needed
      isEnclosed = false;
    }

    return isEnclosed;
  }

  /// The minimum percentage of the character's height required for a vertical line to be considered valid.
  final double _thresholdLinePercentage = 0.7;

  /// Checks if the given matrix contains a vertical line on the left side.
  ///
  /// This function scans the matrix from left to right, looking for vertical lines
  /// that meet a minimum height requirement. It uses a helper function
  /// `_isValidVerticalLineLeft` to validate potential vertical lines.
  ///
  /// Parameters:
  /// - [matrix]: A Matrix representing the data to be analyzed.
  ///   Assumed to contain boolean values where true represents a filled cell.
  ///
  /// Returns:
  /// A boolean value indicating whether a valid vertical line was found on the left side.
  ///
  /// Note:
  /// - The minimum height for a vertical line is determined by `_thresholdLinePercentage`,
  ///   which is a constant value representing the percentage of the character's height.
  /// - The function modifies the [visited] matrix in-place to keep track of visited cells.
  bool _hasVerticalLineLeft(final Artifact matrix) {
    final Artifact visited = Artifact(matrix.cols, matrix.rows);

    // We only consider lines that are more than 40% of the character's height
    final int minVerticalLine =
        (matrix.rows * _thresholdLinePercentage).toInt();

    // Iterate over the matrix from left to right
    for (int x = 0; x < matrix.cols; x++) {
      for (int y = 0; y < matrix.rows; y++) {
        // If the current cell is filled and not visited
        if (matrix.cellGet(x, y) && !visited.cellGet(x, y)) {
          // Check if a valid vertical line exists starting from this cell
          if (_isValidVerticalLineLeft(
            minVerticalLine,
            matrix,
            x,
            y,
            visited,
          )) {
            // If a valid line is found, return true
            return true;
          }
        }
      }
    }

    // If no valid vertical line is found, return false
    return false;
  }

  /// Checks if the given matrix contains a vertical line on the right side.
  ///
  /// This function scans the matrix from right to left, looking for vertical lines
  /// that meet a minimum height requirement. It uses a helper function
  /// `_isValidVerticalLineRight` to validate potential vertical lines.
  ///
  /// Parameters:
  /// - [matrix]: A Matrix representing the data to be analyzed.
  ///   Assumed to contain boolean values where true represents a filled cell.
  ///
  /// Returns:
  /// A boolean value indicating whether a valid vertical line was found on the right side.
  ///
  /// Note:
  /// - The minimum height for a vertical line is determined by `_thresholdLinePercentage`,
  ///   which is assumed to be a class-level constant or variable.
  /// - The function modifies the [visited] matrix in-place to keep track of visited cells.
  bool _hasVerticalLineRight(final Artifact matrix) {
    final Artifact visited = Artifact(matrix.cols, matrix.rows);

    // We only consider lines that are more than 40% of the character's height
    final int minVerticalLine =
        (matrix.rows * _thresholdLinePercentage).toInt();

    // Iterate over the matrix from right to left
    for (int x = matrix.cols - 1; x >= 0; x--) {
      for (int y = 0; y < matrix.rows; y++) {
        // If the current cell is filled and not visited
        if (matrix.cellGet(x, y) && !visited.cellGet(x, y)) {
          // Check if a valid vertical line exists starting from this cell
          if (_isValidVerticalLineRight(
            minVerticalLine,
            matrix,
            x,
            y,
            visited,
          )) {
            // If a valid line is found, return true
            return true;
          }
        }
      }
    }

    // If no valid vertical line is found, return false
    return false;
  }

  /// Validates a potential vertical line on the left side of a character.
  ///
  /// This function checks if there's a valid vertical line starting from the given
  /// coordinates (x, y) in the matrix. A valid line must meet the following criteria:
  /// 1. It must be at least [minVerticalLine] pixels long.
  /// 2. It must not have any filled pixels immediately to its left.
  ///
  /// Parameters:
  /// - [minVerticalLine]: The minimum length required for a vertical line to be considered valid.
  /// - [matrix]: The Matrix representing the character or image being analyzed.
  /// - [x]: The x-coordinate of the starting point of the potential line.
  /// - [y]: The y-coordinate of the starting point of the potential line.
  /// - [visited]: A Matrix to keep track of visited pixels.
  ///
  /// Returns:
  /// A boolean value indicating whether a valid vertical line was found (true) or not (false).
  bool _isValidVerticalLineLeft(
    final int minVerticalLine,
    final Artifact matrix,
    final int x,
    int y,
    final Artifact visited,
  ) {
    final int rows = matrix.rows;
    int lineLength = 0;

    // Ensure no filled pixels on the immediate left side at any point
    while (y < rows && matrix.cellGet(x, y)) {
      visited.cellSet(x, y, true);
      lineLength++;

      // If there's a filled pixel to the left of any point in the line, it's invalid
      if (!_validLeftSideLeft(matrix, x, y)) {
        lineLength = 0; // reset
      }
      if (lineLength >= minVerticalLine) {
        return true;
      }
      y++;
    }

    // Only count if the line length is sufficient
    return false;
  }

  /// Validates a potential vertical line on the right side of a character.
  ///
  /// This function checks if there's a valid vertical line starting from the given
  /// coordinates (x, y) in the matrix. A valid line must meet the following criteria:
  /// 1. It must be at least [minVerticalLine] pixels long.
  /// 2. It must not have any filled pixels immediately to its left.
  ///
  /// Parameters:
  /// - [minVerticalLine]: The minimum length required for a vertical line to be considered valid.
  /// - [matrix]: The Matrix representing the character or image being analyzed.
  /// - [x]: The x-coordinate of the starting point of the potential line.
  /// - [y]: The y-coordinate of the starting point of the potential line.
  /// - [visited]: A Matrix to keep track of visited pixels.
  ///
  /// Returns:
  /// A boolean value indicating whether a valid vertical line was found (true) or not (false).
  bool _isValidVerticalLineRight(
    final int minVerticalLine,
    final Artifact matrix,
    final int x,
    int y,
    final Artifact visited,
  ) {
    final int rows = matrix.rows;
    int lineLength = 0;

    // Traverse downwards from the starting point
    while (y < rows && matrix.cellGet(x, y)) {
      visited.cellSet(x, y, true);
      lineLength++;

      // Check if there's a filled pixel to the left of the current point
      if (!_validLeftSideRight(matrix, x, y)) {
        lineLength = 0; // Reset line length if an invalid pixel is found
      }

      // If we've found a line of sufficient length, return true
      if (lineLength >= minVerticalLine) {
        return true;
      }

      y++; // Move to the next row
    }

    // If we've exited the loop, no valid line was found
    return false;
  }

  /// Validates the left side of a potential vertical line in the matrix.
  ///
  /// This function checks if there are any filled pixels immediately to the left of the
  /// given coordinates (x, y) in the matrix. If there are no filled pixels, or if the
  /// starting x-coordinate is 0, the function returns true, indicating a valid left side.
  ///
  /// Parameters:
  /// - [m]: The Matrix representing the character or image being analyzed.
  /// - [x]: The x-coordinate of the starting point of the potential line.
  /// - [y]: The y-coordinate of the starting point of the potential line.
  ///
  /// Returns:
  /// A boolean value indicating whether the left side of the potential vertical line is valid (true) or not (false).
  bool _validLeftSideLeft(
    final Artifact m,
    final int x,
    final int y,
  ) {
    if (x - 1 < 0) {
      return true;
    }

    if (m.cellGet(x - 1, y) == false) {
      return true;
    }
    return false;
  }

  /// Validates the right side of a potential vertical line in the matrix.
  ///
  /// This function checks if there are any filled pixels immediately to the right of the
  /// given coordinates (x, y) in the matrix. If there are no filled pixels, or if the
  /// x-coordinate is at the edge of the matrix, the function returns true, indicating a valid right side.
  ///
  /// Parameters:
  /// - [m]: The Matrix representing the character or image being analyzed.
  /// - [x]: The x-coordinate of the starting point of the potential line.
  /// - [y]: The y-coordinate of the starting point of the potential line.
  ///
  /// Returns:
  /// A boolean value indicating whether the right side of the potential vertical line is valid (true) or not (false).
  bool _validLeftSideRight(
    final Artifact m,
    final int x,
    final int y,
  ) {
    if (x + 1 >= m.cols) {
      return true;
    }

    if (m.cellGet(x + 1, y) == false) {
      return true;
    }
    return false;
  }

  /// Identifies distinct regions in a dilated binary image.
  ///
  /// This function analyzes a dilated image to find connected components that
  /// likely represent characters or groups of characters.
  ///
  /// The algorithm uses direct array access for performance optimization and
  /// employs a flood fill approach to identify connected regions.
  ///
  /// [this] is the preprocessed binary image after dilation.
  ///
  /// Returns:
  ///   A list of [IntRect] objects representing the bounding boxes of identified regions.
  ///   Each rectangle defines the boundaries of a potential character or character group.
  ///   The returned list is sorted using [Artifact.sortRectangles].
  List<IntRect> findSubRegions() {
    // Clear existing regions
    List<IntRect> regions = [];

    // Create a matrix to track visited pixels
    final Artifact visited = Artifact(
      this.cols,
      this.rows,
    );

    final int width = this.cols;
    final int height = this.rows;
    final Uint8List imageData = this.matrix;
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
            this,
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

  /// Finds the connected components (artifacts) in a binary image matrix.
  ///
  /// This method identifies distinct connected regions in the binary image by using
  /// a flood fill algorithm. For each unvisited "on" pixel (value = true), it performs
  /// a flood fill to collect all connected points that form a single artifact.
  ///
  /// The method tracks visited pixels to ensure each pixel is processed only once.
  /// Each connected component is converted to a separate [Artifact] object using
  /// the [Artifact.fromPoints] factory method, which creates a minimal bounding box
  /// containing just the connected region.
  ///
  /// Parameters:
  ///   None - operates on the current [Artifact] instance.
  ///
  /// Returns:
  ///   A list of [Artifact] objects, each representing a distinct connected component
  ///   found in the binary image. The artifacts are sorted using [Artifact.sortMatrices].
  List<Artifact> findSubArtifacts() {
    // Clear existing regions
    List<Artifact> regions = [];

    // Create a matrix to track visited pixels
    final Artifact visited = Artifact(this.cols, this.rows);

    // Scan through each pixel
    for (int y = 0; y < this.rows; y++) {
      for (int x = 0; x < this.cols; x++) {
        // If pixel is on and not visited, flood fill from this point
        if (!visited.cellGet(x, y) && this.cellGet(x, y)) {
          // Get connected points using flood fill
          final List<Point<int>> connectedPoints = floodFill(
            this,
            visited,
            x,
            y,
          );

          if (connectedPoints.isEmpty) {
            continue;
          }
          regions.add(Artifact.fromPoints(connectedPoints));
        }
      }
    }

    Artifact.sortMatrices(regions);
    return regions;
  }
}

import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:textify/int_rect.dart';

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
    final int cols = (json['cols'] as int?) ??
        (json['data'] as List<dynamic>)[0].toString().length;

    final Artifact artifact = Artifact(cols, 0);
    artifact.font = json['font'];
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

  /// The character that this artifact matches.
  String characterMatched = '';

  /// Tag the artifact as needs more attentions
  bool needsInspection = false;

  ///
  bool wasPartOfSplit = false;

  /// Empty the content
  void clear() {
    this.cols = 0;
    this._matrix = Uint8List(0);
  }

  /// Converts the artifact to a text representation.
  ///
  /// Parameters:
  /// - onChar: The character to use for 'on' pixels (default: '#').
  /// - forCode: Whether the output is intended for code representation (default: false).
  ///
  /// Returns:
  /// A string representation of the artifact.
  String toText({
    final String onChar = '#',
    final bool forCode = false,
  }) {
    return this.gridToString(
      forCode: forCode,
      onChar: onChar,
    );
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
    Artifact.copyGrid(
      this,
      newGrid,
      (this.rectFound.left - newRect.left),
      (this.rectFound.top - newRect.top),
    );

    Artifact.copyGrid(
      toMerge,
      newGrid,
      (toMerge.rectFound.left - newRect.left),
      (toMerge.rectFound.top - newRect.top),
    );

    // Update this artifact with the merged data
    this.setGrid(newGrid._matrix, newGrid.cols);
  }

  /// Returns:
  /// A string representation ths artifact.
  @override
  String toString() {
    return '"$characterMatched" left:${locationFound.x} top:${locationFound.y} CW:${rectFound.width} CH:${rectFound.height} isEmpty:$isEmpty E:$enclosures LL:$verticalLineLeft LR:$verticalLineRight';
  }

  /// Creates a new Matrix by taking the vertical projection of the source Matrix.
  ///
  /// The vertical projection of a Matrix is a new Matrix where each column in the
  /// result contains a boolean value indicating whether there is a true value in
  /// that column of the source Matrix.
  ///
  /// [source] The source Matrix to take the vertical projection of.
  /// Returns a new Matrix with the same number of rows as the source, and a number
  /// of columns equal to the number of columns in the source.
  Artifact getHistogramHorizontalArtifact() {
    int width = this.cols;

    // Step 1: Compute vertical projection (count active pixels per column)
    List<int> histogram = getHistogramHorizontal();

    // Step 2: Create an empty matrix for the projection
    Artifact result = Artifact(this.cols, this.rows);

    // Step 3: Fill the matrix from the bottom up based on the projection counts
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < histogram[x]; y++) {
        result.cellSet(x, this.rows - 1 - y, true);
      }
    }

    return result;
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
  static Future<Artifact> fromImage(final Image image) async {
    final Uint8List uint8List = await imageToUint8List(image);
    return Artifact.fromUint8List(uint8List, image.width);
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

  ///
  bool discardableContent() {
    return (this.rectFound.width * this.rectFound.height) <= 2 ||
        isConsideredLine();
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
  static void copyGrid(
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

  /// Creates a new Matrix by cropping the current Matrix to the specified boundaries.
  ///
  /// Parameters:
  /// - `bottomRow`: The bottom row index of the crop area (inclusive). Defaults to 0.
  /// - `topRow`: The top row index of the crop area (inclusive). Defaults to 0.
  /// - `leftCol`: The left column index of the crop area (inclusive). Defaults to 0.
  /// - `rightCol`: The right column index of the crop area (inclusive). Defaults to 0.
  ///
  /// Returns:
  /// A new Matrix containing the cropped section of the original Matrix.
  void cropBy({
    int left = 0,
    int top = 0,
    int right = 0,
    int bottom = 0,
  }) {
    this.locationFound = this.locationFound.translate(left, top);
    this.locationAdjusted = this.locationAdjusted.translate(left, top);
    cropGridVertically(top: top, bottom: bottom);
  }

  /// Crops the matrix vertically by removing a specified number of rows from the top and bottom.
  ///
  /// This method modifies the matrix in-place by removing rows from the top and bottom.
  /// If the matrix is empty, no action is taken. The number of rows to remove is clamped
  /// to prevent out-of-range errors.
  ///
  /// Parameters:
  /// - `top`: Number of rows to remove from the top of the matrix. Defaults to 0.
  /// - `bottom`: Number of rows to remove from the bottom of the matrix. Defaults to 0.
  void cropGridVertically({int top = 0, int bottom = 0}) {
    if (rows == 0) {
      return;
    }

    // Clamp values to avoid out-of-range errors
    top = top.clamp(0, rows);
    bottom = bottom.clamp(0, rows - top);

    // Remove top rows
    _matrix.removeRange(0, top);

    // Remove bottom rows
    _matrix.removeRange(rows - bottom, rows);
  }

  /// Creates a new Matrix with the specified desired width and height, by resizing the current Matrix.
  ///
  /// If the current Matrix is punctuation, it will not be cropped and will be centered in the new Matrix.
  /// Otherwise, the current Matrix will be trimmed and then wrapped with false values before being resized.
  ///
  /// Parameters:
  /// - `desiredWidth`: The desired width of the new Matrix.
  /// - `desiredHeight`: The desired height of the new Matrix.
  ///
  /// Returns:
  /// A new Matrix with the specified dimensions, containing a resized version of the original Matrix's content.
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
  /// surrounded by true cells. This getter calculates the number of such
  /// regions in the matrix.
  ///
  /// The calculation is performed only once and the result is cached for
  /// subsequent calls to improve performance.
  ///
  /// Returns:
  /// An integer representing the number of enclosed regions in the matrix.
  ///
  /// Note: The actual counting is performed by the `countEnclosedRegion`
  /// function, which is assumed to be defined elsewhere in the class or
  /// imported from another file.
  int get enclosures {
    if (_enclosures == -1) {
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
  static Artifact extractSubGrid({
    required final Artifact matrix,
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

        if (sourceX < matrix.cols && sourceY < matrix.rows) {
          subImagePixels.cellSet(x, y, matrix.cellGet(sourceX, sourceY));
        }
      }
    }

    subImagePixels.locationFound = rect.shift(matrix.rectFound.topLeft).topLeft;
    subImagePixels.locationAdjusted =
        rect.shift(matrix.rectAdjusted.topLeft).topLeft;

    return subImagePixels;
  }

  /// Splits the given matrix into multiple row matrices based on the provided row offsets.
  ///
  /// Each row offset in [rowOffsets] marks the start of a new split.
  /// The function returns a list of [Artifact] objects, where each matrix represents
  /// a horizontal slice of the original [input] matrix while maintaining its relative position.
  ///
  /// Example:
  /// ```dart
  /// Matrix input = Matrix(5, 5);
  /// List<int> rowOffsets = [0, 2, 4]; // Splits at row indices 0, 2, and 4
  /// List<Matrix> rowMatrices = Matrix.splitAsRows(input, rowOffsets);
  /// ```
  ///
  /// - [input]: The original matrix to split.
  /// - [rowOffsets]: A list of row indices where splits should occur.
  /// - Returns: A list of matrices representing the split rows while preserving `locationFound`.
  static List<Artifact> splitAsRows(
    final Artifact input,
    List<int> rowOffsets,
  ) {
    List<Artifact> result = [];

    for (int i = 0; i < rowOffsets.length; i++) {
      int startRow = rowOffsets[i];
      int endRow = (i < rowOffsets.length - 1) ? rowOffsets[i + 1] : input.rows;

      // Create a new matrix with the same width but only the selected row range
      Artifact rowArtifact = Artifact(input.cols, endRow - startRow);

      // Copy the relevant rows from input to rowMatrix
      for (int y = startRow; y < endRow; y++) {
        for (int x = 0; x < input.cols; x++) {
          rowArtifact.cellSet(x, y - startRow, input.cellGet(x, y));
        }
      }

      // Adjust locationFound based on the original matrix
      rowArtifact.locationFound = IntOffset(
        input.locationFound.x, // Keep the same X position
        input.locationFound.y +
            startRow, // Adjust the Y position based on the split
      );

      result.add(rowArtifact);
    }

    return result;
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
  static List<Artifact> splitAsColumns(
    final Artifact artifactToSplit,
    List<int> offsets,
  ) {
    List<Artifact> result = [];

    for (int i = 0; i < offsets.length - 1; i++) {
      int columnStart = offsets[i];
      int columnEnd =
          (i < offsets.length - 1) ? offsets[i + 1] : artifactToSplit.cols;

      // Create a new matrix with the same width but only the selected row range
      Artifact artifact =
          Artifact(columnEnd - columnStart, artifactToSplit.rows);

      // Copy the relevant columns from input to rowMatrix
      for (int x = columnStart; x < columnEnd; x++) {
        for (int y = 0; y < artifactToSplit.rows; y++) {
          artifact.cellSet(x - columnStart, y, artifactToSplit.cellGet(x, y));
        }
      }

      // Set locationFound based on the original matrix
      artifact.locationFound = IntOffset(
        // Adjust the X position based on the split
        artifactToSplit.locationFound.x + columnStart,
        // Keep the same X position
        artifactToSplit.locationFound.y,
      );

      // Set locationAdjusted
      artifact.locationAdjusted = IntOffset(
        // Adjust the X position based on the split
        artifactToSplit.locationAdjusted.x + columnStart,
        // Keep the same X position
        artifactToSplit.locationAdjusted.y,
      );
      artifact.wasPartOfSplit = true;
      result.add(artifact);
    }

    return result;
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

  ///
  /// Calculates the content rectangle adjusted by the top-left position of the current rectangle.
  ///
  /// Returns:
  /// An IntRect representing the content rectangle shifted to account for the current rectangle's position.
  ///
  /// This method is useful for obtaining the content rectangle relative to the adjusted rectangle's coordinate system.
  IntRect getContentRectAdjusted() {
    return getContentRect().shift(this.rectAdjusted.topLeft);
  }

  /// Creates a string representation of two overlaid matrices.
  ///
  /// This static method compares two matrices cell by cell and generates a new
  /// representation where each cell is represented by a character based on the
  /// values in both input matrices.
  ///
  /// Parameters:
  /// - [grid1]: The first Matrix to be overlaid.
  /// - [grid2]: The second Matrix to be overlaid.
  ///
  /// Returns:
  /// A ```List<String>``` where each string represents a row in the overlaid result.
  /// The characters in the resulting strings represent:
  ///   '=' : Both matrices have true in this cell
  ///   '*' : Only grid1 has true in this cell
  ///   '#' : Only grid2 has true in this cell
  ///   '.' : Both matrices have false in this cell
  ///
  /// Throws:
  /// An Exception if the input matrices have different dimensions.
  ///
  /// Note:
  /// This method is useful for visualizing the differences and similarities
  /// between two matrices, which can be helpful in debugging or analysis tasks.
  static List<String> getStringListOfOverlappedGrids(
    final Artifact grid1,
    final Artifact grid2,
  ) {
    final int height = grid1.rows;
    final int width = grid1.cols;

    if (height != grid2.rows || width != grid2.cols) {
      throw Exception('Grids must have the same dimensions');
    }

    final List<String> overlappedGrid = [];

    for (int row = 0; row < height; row++) {
      String overlappedRow = '';

      for (int col = 0; col < width; col++) {
        final bool cell1 = grid1.cellGet(col, row);
        final bool cell2 = grid2.cellGet(col, row);

        if (cell1 && cell2) {
          overlappedRow += '=';
        } else if (cell1) {
          overlappedRow += '*';
        } else if (cell2) {
          overlappedRow += '#';
        } else {
          overlappedRow += '.';
        }
      }

      overlappedGrid.add(overlappedRow);
    }

    return overlappedGrid;
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
  static double hammingDistancePercentage(
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

  /// Custom comparison method for matrices
  static bool matrixEquals(Artifact a, Artifact b) {
    // Check if dimensions are the same
    if (a.rows != b.rows || a.cols != b.cols) {
      return false;
    }

    // Compare each cell
    for (int y = 0; y < a.rows; y++) {
      for (int x = 0; x < a.cols; x++) {
        if (a.cellGet(x, y) != b.cellGet(x, y)) {
          return false;
        }
      }
    }

    // If we've made it this far, the matrices are equal
    return true;
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

  ///
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
  int _countEnclosedRegion(final Artifact grid) {
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

  ///
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

  ///
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
  int _exploreRegion(
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
  bool _isEnclosedRegion(
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
}

/// Converts a UI image to a black and white image by applying an adaptive threshold.
///
/// This function takes a UI image, converts it to grayscale, and then applies an adaptive
/// threshold to convert the image to black and white. The adaptive threshold is computed
/// by taking the average of all the pixel values and subtracting 90 from it, which helps
/// to create a sharper separation between the foreground and background.
///
/// Parameters:
/// - [inputImage]: The input UI image to be converted.
/// - [backgroundBrightnessThreshold_0_255]: The brightness threshold for the background, between 0 and 255. Defaults to 190.
///
/// Returns:
/// A Future that resolves to the converted black and white UI image.
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

/// Performs an erosion operation on the input image.
///
/// This function takes a [Image] and performs an erosion operation on it.
/// The erosion operation shrinks the black pixels (letters) against the white background.
///
/// Parameters:
/// - [inputImage]: The source image to be eroded (black and white).
/// - [kernelSize]: The size of the erosion kernel (must be an odd number).
///
/// Returns:
/// A [Future] that resolves to a [Image] containing the eroded image.
Future<Image> erode(
  final Image inputImage, {
  final int kernelSize = 3,
}) async {
  final int width = inputImage.width;
  final int height = inputImage.height;

  // Get the pixel data from the input image
  final ByteData? byteData =
      await inputImage.toByteData(format: ImageByteFormat.rawRgba);
  if (byteData == null) {
    throw Exception('Failed to get image data');
  }
  final Uint8List inputPixels = byteData.buffer.asUint8List();

  // Create a new Uint8List for the output image
  final Uint8List outputPixels = Uint8List(width * height * 4);

  // Calculate the radius of the kernel
  final int radius = kernelSize ~/ 2;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      // Initialize the maximum value to black (0)
      int maxValue = 0;

      // Check the kernel area
      for (int ky = -radius; ky <= radius; ky++) {
        for (int kx = -radius; kx <= radius; kx++) {
          // Calculate the index of the neighbor pixel
          int neighborX = x + kx;
          int neighborY = y + ky;

          // Ensure we stay within bounds
          if (neighborX >= 0 &&
              neighborX < width &&
              neighborY >= 0 &&
              neighborY < height) {
            // Get the pixel value (assuming binary image, check the red channel)
            int pixelIndex = (neighborY * width + neighborX) * 4; // RGBA
            int r =
                inputPixels[pixelIndex]; // Assuming grayscale, use red channel

            // Update the maximum value
            maxValue = max(maxValue, r);
          }
        }
      }

      // Set the eroded pixel value in the output image
      int outputIndex = (y * width + x) * 4;
      outputPixels[outputIndex] = maxValue; // R
      outputPixels[outputIndex + 1] = maxValue; // G
      outputPixels[outputIndex + 2] = maxValue; // B
      outputPixels[outputIndex + 3] = 255; // A (fully opaque)
    }
  }

  // Create a new Image from the output pixels
  final ImmutableBuffer buffer =
      await ImmutableBuffer.fromUint8List(outputPixels);
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
  final Uint8List imageData = dilatedMatrixImage._matrix;
  final Uint8List visitedData = visited._matrix;

  // Scan through each pixel - use direct array access
  for (int y = 0; y < height; y++) {
    final int rowOffset = y * width;
    for (int x = 0; x < width; x++) {
      final int index = rowOffset + x;
      // Check if pixel is on and not visited using direct array access
      if (visitedData[index] == 0 && imageData[index] == 1) {
        final List<Point<int>> connectedPoints = floodFill(
          dilatedMatrixImage,
          visited,
          x,
          y,
        );

        if (connectedPoints.isNotEmpty) {
          regions.add(rectFromPoints(connectedPoints));
        }
      }
    }
  }

  Artifact.sortRectangles(regions);
  return regions;
}

/// Performs a flood fill algorithm on a binary image matrix.
///
/// This method implements a depth-first search flood fill algorithm to find
/// all connected points starting from a given point in a binary image.
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
///
/// Throws:
///   An assertion error if the areas of [binaryPixels] and [visited] are not equal.
List<Point<int>> floodFill(
  final Artifact binaryPixels,
  final Artifact visited,
  final int startX,
  final int startY,
) {
  assert(binaryPixels.area == visited.area);

  final int width = binaryPixels.cols;
  final Uint8List pixelData = binaryPixels._matrix;
  final Uint8List visitedData = visited._matrix;

  // Pre-allocate with a reasonable capacity to reduce reallocations
  final List<Point<int>> connectedPoints = <Point<int>>[];

  // Use a more efficient queue implementation for large flood fills
  final Queue<int> queue = Queue<int>();

  // Store indices directly instead of Point objects to reduce allocations
  final int startIndex = startY * width + startX;
  queue.add(startIndex);
  visitedData[startIndex] = 1;

  // Pre-compute direction offsets
  final List<int> dirOffsets = [-1, 1, -width, width]; // left, right, up, down

  while (queue.isNotEmpty) {
    final int currentIndex = queue.removeFirst();
    final int x = currentIndex % width;
    final int y = currentIndex ~/ width;

    // Add point to result list
    connectedPoints.add(Point(x, y));

    // Check all four directions
    for (final int offset in dirOffsets) {
      final int neighborIndex = currentIndex + offset;

      // Skip out-of-bounds checks for left/right edges
      if ((offset == -1 && x == 0) || (offset == 1 && x == width - 1)) {
        continue;
      }

      // Skip out-of-bounds indices
      if (neighborIndex < 0 || neighborIndex >= pixelData.length) {
        continue;
      }

      // Check if the neighbor is valid and not visited
      if (pixelData[neighborIndex] == 1 && visitedData[neighborIndex] == 0) {
        queue.add(neighborIndex);
        visitedData[neighborIndex] = 1;
      }
    }
  }

  return connectedPoints;
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

///
IntRect rectFromPoints(List<Point<int>> connectedPoints) {
  // Create a new matrix for the isolated region
  final int minX = connectedPoints.map((point) => point.x).reduce(min);
  final int minY = connectedPoints.map((point) => point.y).reduce(min);
  final int maxX = connectedPoints.map((point) => point.x).reduce(max);
  final int maxY = connectedPoints.map((point) => point.y).reduce(max);

  final int regionWidth = maxX - minX + 1;
  final int regionHeight = maxY - minY + 1;

  final IntRect region = IntRect.fromLTWH(
    minX,
    minY,
    regionWidth,
    regionHeight,
  );

  return region;
}

// (int minX, int minY, int maxX, int maxY) calculateBoundingBox(
//   List<Point> points,
// ) {
//   int minX = double.infinity.toInt();
//   int minY = double.infinity.toInt();
//   int maxX = -double.infinity.toInt();
//   int maxY = -double.infinity.toInt();

//   for (final Point<num> point in points) {
//     if (point.x < minX) minX = point.x.toInt();
//     if (point.y < minY) minY = point.y.toInt();
//     if (point.x > maxX) maxX = point.x.toInt();
//     if (point.y > maxY) maxY = point.y.toInt();
//   }

//   return (minX, minY, maxX, maxY);
// }

///
int computeKernelSize(int width, int height, double scaleFactor) {
  return (scaleFactor * width).round().clamp(1, width);
}

/// Performs a dilation operation on the input matrix.
///
/// This function takes a [Artifact] and performs a dilation operation on it.
/// The dilation operation expands the black pixels against the white background.
///
/// Parameters:
/// - [matrixImage]: The source matrix to be dilated (binary matrix).
/// - [kernelSize]: The size of the kernel to use for dilation.
///
/// Returns:
/// A new [Artifact] containing the dilated matrix.
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

///
int calculateThreshold(List<int> histogram) {
  if (histogram.length < 3) {
    return -1;
  }

  // Find the valleys (local minima)
  List<int> valleys = [];
  for (int i = 1; i < histogram.length - 1; i++) {
    if (histogram[i] < histogram[i - 1] && histogram[i] < histogram[i + 1]) {
      valleys.add(histogram[i]);
    }
  }

  // Calculate the average height of the histogram (representing the typical character height)
  double averageHeight = histogram.reduce((a, b) => a + b) / histogram.length;

  // Set a threshold as a value below the average to split touching characters
  // This could be a percentage of the average height or a fixed offset.
  double threshold =
      averageHeight * 0.5; // You can adjust this factor (0.5) as needed

  // Optionally, you can adjust this threshold based on the local minima values:
  if (valleys.isNotEmpty) {
    threshold = valleys.reduce((a, b) => a < b ? a : b) *
        0.8; // Adjust threshold based on valleys
  }

  return threshold.toInt();
}

///
/// Splits a given matrix into row sections based on vertical histogram valleys.
///
/// - A valley is a row where the histogram value is **0**, meaning no data exists there.
/// - These valleys act as separators for different row sections.
/// - The function preserves each section's `locationFound` relative to the original.
///
/// Example:
/// ```dart
/// Matrix region = Matrix(10, 10);
/// List<Matrix> rows = splitRegionIntoRows(region);
/// ```
///
/// - [region]: The input matrix to be split.
/// - Returns: A list of matrix sections split by empty rows.
List<Artifact> splitRegionIntoRows(Artifact matrixImage) {
  // Compute the vertical histogram (column-wise pixel count per row).
  final List<int> histogramAll = matrixImage.getHistogramVertical();

  // Find row indices where the histogram is **0**, meaning empty rows.
  final List<int> rowSeparators = keepIndexBelowValue(histogramAll, 0);
  if (rowSeparators.isEmpty) {
    return [matrixImage]; // no need to split
  }

  // Ensure the first and last rows are included as split points.
  if (rowSeparators.first != 0) {
    rowSeparators.insert(0, 0);
  }
  if (rowSeparators.last != matrixImage.rectFound.height) {
    rowSeparators.add(matrixImage.rectFound.height.toInt());
  }

  // Split the region into meaningful row sections.
  final List<Artifact> regionAsRows =
      Artifact.splitAsRows(matrixImage, rowSeparators);

  return regionAsRows;
}

///
List<int> keepIndexBelowValue(final List<int> histogram, final int maxValue) {
  List<int> indexes = [];

  // Find the first index that does not match the threshold
  int startIndex = -1;
  for (int i = 0; i < histogram.length; i++) {
    if (histogram[i] > maxValue) {
      startIndex = i + 1;
      break;
    }
  }

  // If no valid start index is found, return an empty list
  if (startIndex == -1) {
    return indexes;
  }

  // Find the last index that does not match the threshold
  int endIndex = histogram.length;
  for (int i = histogram.length - 1; i >= 0; i--) {
    if (histogram[i] > maxValue) {
      endIndex = i;
      break;
    }
  }

  // Collect all indexes between startIndex and endIndex
  for (int i = startIndex; i < endIndex; i++) {
    if (histogram[i] <= maxValue) {
      indexes.add(i);
    }
  }

  return indexes;
}

///
void offsetMatrices(final List<Artifact> matrices, final int x, final int y) {
  matrices.forEach(
    (matrix) => matrix.locationFound = matrix.locationFound.translate(x, y),
  );
}

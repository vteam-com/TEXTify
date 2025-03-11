import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui;

/// Represents a 2D grid of boolean values, primarily used for image processing
/// and pattern recognition tasks.
///
/// This class provides various ways to create, manipulate, and analyze boolean matrices,
/// including methods for resizing, comparing, and extracting information from the grid.
class Matrix {
  /// Creates a new Matrix with the specified dimensions, filled with the given value.
  ///
  /// [cols] The number of columns in the matrix.
  /// [rows] The number of rows in the matrix.
  /// [value] The initial value for all cells (default is false).
  Matrix([
    final num cols = 0,
    final num rows = 0,
    final bool value = false,
  ]) {
    _data = List.generate(
      rows.toInt(),
      (_) => List.filled(cols.toInt(), false),
    );
    this.cols = cols.toInt();
    this.rows = rows.toInt();
  }

  /// Creates a new [Matrix] instance from an existing [Matrix].
  ///
  /// This factory method creates a new [Matrix] instance based on the provided [value] matrix.
  /// It copies the grid data and the rectangle properties from the input matrix.
  ///
  /// Parameters:
  /// - [value]: The source [Matrix] instance to copy from.
  ///
  /// Returns:
  /// A new [Matrix] instance with the same grid data and rectangle as the input matrix.
  ///
  /// Note: This method creates a shallow copy of the grid data. If deep copying of the data
  /// is required, consider implementing a separate deep copy method.
  ///
  /// Example:
  /// ```dart
  /// Matrix original = Matrix(/* ... */);
  /// Matrix copy = Matrix.fromMatrix(original);
  /// ```
  factory Matrix.fromMatrix(final Matrix value) {
    final matrix = Matrix();
    matrix.setGrid(value.data);
    matrix.originRectangle = value.originRectangle;
    return matrix;
  }

  /// Creates a Matrix from an ASCII representation.
  ///
  /// [template] A list of strings where '#' represents true and any other character represents false.
  factory Matrix.fromAsciiDefinition(final List<String> template) {
    final Matrix matrix = Matrix();
    matrix.rows = template.length;
    matrix.cols = template[0].length;
    matrix._data = List.generate(
      matrix.rows,
      (y) => List.generate(matrix.cols, (x) => template[y][x] == '#'),
    );
    return matrix;
  }

  /// Creates a Matrix from an existing 2D boolean list.
  ///
  /// [input] A 2D list of boolean values.
  factory Matrix.fromBoolMatrix(final List<List<bool>> input) {
    final Matrix matrix = Matrix();
    matrix.setGrid(input);
    return matrix;
  }

  /// Creates a Matrix from a flat list of boolean values.
  ///
  /// [inputList] A flat list of boolean values.
  /// [width] The width of the resulting matrix.
  factory Matrix.fromFlatListOfBool(
    final List<bool> inputList,
    final int width,
  ) {
    final Matrix matrix = Matrix();
    matrix.rows = inputList.length ~/ width;
    matrix.cols = width;

    for (int y = 0; y < matrix.rows; y++) {
      matrix._data
          .add(inputList.sublist(y * matrix.cols, (y + 1) * matrix.cols));
    }
    return matrix;
  }

  /// Creates a Matrix from JSON data.
  ///
  /// [json] A map containing 'rows', 'cols', and 'data' keys.
  factory Matrix.fromJson(final Map<String, dynamic> json) {
    final Matrix matrix = Matrix();
    matrix.font = json['font'];
    matrix.rows = json['rows'];
    matrix.cols = json['cols'];
    matrix._data = (json['data'] as List<dynamic>).map((row) {
      return row.toString().split('').map((cell) => cell == '#').toList();
    }).toList();
    return matrix;
  }

  /// Creates a Matrix from a Uint8List, typically used for image data.
  ///
  /// [pixels] A Uint8List representing pixel data.
  /// [width] The width of the image.
  factory Matrix.fromUint8List(
    final Uint8List pixels,
    final int width,
  ) {
    return Matrix.fromFlatListOfBool(
      [
        for (int i = 0; i < pixels.length; i += 4) pixels[i] == 0,
      ],
      width,
    );
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
  Matrix verticalProjection() {
    int width = this.cols;

    // Step 1: Compute vertical projection (count active pixels per column)
    List<int> projection = List.filled(width, 0);
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < this.rows; y++) {
        if (this.data[y][x]) {
          projection[x]++;
        }
      }
    }

    // Step 2: Create an empty matrix for the projection
    Matrix result = Matrix(this.cols, this.rows, false);

    // Step 3: Fill the matrix from the bottom up based on the projection counts
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < projection[x]; y++) {
        result._data[this.rows - 1 - y][x] = true; // Fill from bottom up
      }
    }

    return result;
  }

  /// Creates a [Matrix] from a [ui.Image].
  ///
  /// This factory constructor takes a [ui.Image] object and transforms it into a [Matrix]
  /// representation. The process involves two main steps:
  /// 1. Converting the image to a Uint8List using [imageToUint8List].
  /// 2. Creating a Matrix from the Uint8List using [Matrix.fromUint8List].
  ///
  /// [image] The ui.Image object to be converted. This should be a valid,
  /// non-null image object.
  ///
  /// Returns a [Future<Matrix>] representing the image data. The returned Matrix
  /// will have the same width as the input image, and its height will be
  /// determined by the length of the Uint8List and the width.
  ///
  /// Throws an exception if [imageToUint8List] fails to convert the image or if
  /// [Matrix.fromUint8List] encounters an error during matrix creation.
  ///
  /// Note: This constructor is asynchronous due to the [imageToUint8List] operation.
  /// Ensure to await its result when calling.
  static Future<Matrix> fromImage(final ui.Image image) async {
    final Uint8List uint8List = await imageToUint8List(image);
    return Matrix.fromUint8List(uint8List, image.width);
  }

  /// Font this matrix template is based on
  String font = '';

  /// The number of columns in the matrix.
  int cols = 0;

  /// The number of rows in the matrix.
  int rows = 0;

  /// The 2D list representing the boolean grid.
  /// Each outer list represents a row, and each inner list represents a column.
  /// _data[row][column] gives the boolean value at that position.
  List<List<bool>> _data = [];

  /// Returns the matrix data as a 2D list of boolean values.
  /// The outer list represents rows and the inner lists represent columns.
  /// Each boolean value indicates whether a cell is active (true) or inactive (false).
  List<List<bool>> get data => _data;

  /// the rectangle location of this matrix.
  Rect originRectangle = Rect.zero;

  /// The number of enclosure found
  int _enclosures = -1;

  /// The number of vertical left lines found
  bool? _verticalLineLeft;

  /// The number of vertical right lines found
  bool? _verticalLineRight;

  /// Area size of the matrix
  int get area => cols * rows;

  /// Calculates the aspect ratio of the content within the matrix.
  ///
  /// Returns the height-to-width ratio of the bounding box containing all true cells.
  double aspectRatioOfContent() {
    final Size size = _getContentSize();
    return size.height / size.width; // Aspect ratio
  }

  /// Retrieves the value of a cell at the specified coordinates.
  ///
  /// Returns false if the coordinates are out of bounds.
  bool cellGet(final int x, final int y) {
    if (_isValidXY(x, y)) {
      return _data[y][x];
    }
    return false;
  }

  /// Sets the value of a cell at the specified coordinates.
  ///
  /// Does nothing if the coordinates are out of bounds.
  void cellSet(final int x, final int y, bool value) {
    if (_isValidXY(x, y)) {
      _data[y][x] = value;
    }
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
    final Matrix source,
    final Matrix target,
    final int offsetX,
    final int offsetY,
  ) {
    for (int y = 0; y < source.rows; y++) {
      for (int x = 0; x < source.cols; x++) {
        if (y + offsetY < target.rows && x + offsetX < target.cols) {
          target._data[y + offsetY][x + offsetX] |= source._data[y][x];
        }
      }
    }
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
  Matrix trim() {
    if (isEmpty || isEmpty) {
      return Matrix();
    }
    // Find the boundaries of the content
    int topRow = 0;
    int bottomRow = rows - 1;
    int leftCol = 0;
    int rightCol = cols - 1;

    // Find top row with content
    while (topRow < rows && !_data[topRow].contains(true)) {
      topRow++;
    }

    // Find bottom row with content
    while (bottomRow > topRow && !_data[bottomRow].contains(true)) {
      bottomRow--;
    }

    // Find left column with content
    outer:
    while (leftCol < cols) {
      for (int i = topRow; i <= bottomRow; i++) {
        if (_data[i][leftCol]) {
          break outer;
        }
      }
      leftCol++;
    }

    // Find right column with content
    outer:
    while (rightCol > leftCol) {
      for (int i = topRow; i <= bottomRow; i++) {
        if (_data[i][rightCol]) {
          break outer;
        }
      }
      rightCol--;
    }

    // Crop the grid
    return Matrix.fromBoolMatrix(
      List.generate(
        bottomRow - topRow + 1,
        (i) => _data[i + topRow].sublist(leftCol, rightCol + 1),
      ),
    );
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
  Matrix createNormalizeMatrix(
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

  /// Returns:
  /// A string representation ths Matrix.
  @override
  String toString() {
    final Size size = _getContentSize();
    return 'W:$cols H:$rows CW:${size.width} CH:${size.height} isEmpty:$isEmpty E:$enclosures LL:$verticalLineLeft LR:$verticalLineRight';
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
  Matrix _createResizedGrid(final int targetWidth, final int targetHeight) {
    // Initialize the resized grid
    final Matrix resizedGrid = Matrix(targetWidth, targetHeight);

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
          resizedGrid._data[y][x] = _data[srcYInt][srcXInt];
        } else {
          // DownScaling: Check for any black pixel in the sub-grid
          final int startX = srcX.floor();
          final int endX = (srcX + xScale).ceil();
          final int startY = srcY.floor();
          final int endY = (srcY + yScale).ceil();

          bool hasBlackPixel = false;

          for (int sy = startY; sy < endY && sy < rows; sy++) {
            for (int sx = startX; sx < endX && sx < cols; sx++) {
              if (_data[sy][sx]) {
                hasBlackPixel = true;
                break;
              }
            }
            if (hasBlackPixel) {
              break;
            }
          }

          // Set the resized grid value based on the presence of any black pixel
          resizedGrid._data[y][x] = hasBlackPixel;
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
    final blankLine = List.filled(cols, false);

    for (int add = 0; add < paddingTop; add++) {
      this._data.insert(0, blankLine);
    }

    for (int add = 0; add < paddingBottom; add++) {
      this._data.add(blankLine);
    }
    this.rows = _data.length;
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
  Matrix _createWrapGridWithFalse() {
    if (isEmpty) {
      return Matrix.fromBoolMatrix([
        [false, false],
        [false, false],
        [false, false],
      ]);
    }

    // Create a new grid with increased dimensions
    final Matrix newGrid = Matrix.fromBoolMatrix(
      List.generate(
        rows + 2,
        (r) => List.generate(cols + 2, (c) => false),
      ),
    );

    // Copy the original grid into the center of the new grid
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        newGrid._data[r + 1][c + 1] = _data[r][c];
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
  /// - [binaryImage]: The source Matrix from which to extract the sub-grid.
  /// - [rect]: A Rect object specifying the region to extract. The rectangle's
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
  static Matrix extractSubGrid({
    required final Matrix binaryImage,
    required final Rect rect,
  }) {
    final int startX = rect.left.toInt();
    final int startY = rect.top.toInt();
    final int subImageWidth = rect.width.toInt();
    final int subImageHeight = rect.height.toInt();

    final Matrix subImagePixels = Matrix(subImageWidth, subImageHeight, false);

    for (int x = 0; x < subImageWidth; x++) {
      for (int y = 0; y < subImageHeight; y++) {
        final int sourceX = startX + x;
        final int sourceY = startY + y;

        if (sourceX < binaryImage.cols && sourceY < binaryImage.rows) {
          subImagePixels.cellSet(x, y, binaryImage.cellGet(sourceX, sourceY));
        }
      }
    }

    return subImagePixels;
  }

  /// Calculates the size of the content area in the matrix.
  ///
  /// This method determines the dimensions of the smallest rectangle that
  /// encompasses all true cells in the matrix. It uses the `getContentRect`
  /// method to find the bounding rectangle and then returns its size.
  ///
  /// Returns:
  /// A Size object representing the width and height of the content area.
  ///
  /// If the matrix is empty or contains no true cells, it returns a Size
  /// with zero width and height.
  ///
  /// Note:
  /// - The returned Size uses double values for width and height to be
  ///   compatible with Flutter's Size class.
  /// - This method is a convenient way to get the dimensions of the content
  ///   without needing the full Rect information.
  Size _getContentSize() {
    return getContentRect().size;
  }

  /// Calculates the bounding rectangle of the content in the matrix.
  ///
  /// This method finds the smallest rectangle that encompasses all true cells
  /// in the matrix. It's useful for determining the area of the matrix that
  /// contains actual content.
  ///
  /// Returns:
  /// A Rect object representing the bounding rectangle of the content.
  /// The rectangle is defined by its left, top, right, and bottom coordinates.
  ///
  /// If the matrix is empty or contains no true cells, it returns Rect.zero.
  ///
  /// Note:
  /// - The returned Rect uses double values for coordinates to be compatible
  ///   with Flutter's Rect class.
  /// - The right and bottom coordinates are exclusive (i.e., they point to
  ///   the cell just after the last true cell in each direction).
  Rect getContentRect() {
    int minX = cols;
    int maxX = -1;
    int minY = rows;
    int maxY = -1;

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        if (_data[y][x]) {
          minX = min(minX, x);
          maxX = max(maxX, x);
          minY = min(minY, y);
          maxY = max(maxY, y);
        }
      }
    }

    // If no content found, return Rect.zero
    if (maxX == -1 || maxY == -1) {
      return Rect.zero;
    } else {
      return Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        (maxX + 1).toDouble(),
        (maxY + 1).toDouble(),
      );
    }
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
    final Matrix grid1,
    final Matrix grid2,
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
        final bool cell1 = grid1._data[row][col];
        final bool cell2 = grid2._data[row][col];

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
  /// Example:
  /// ```dart
  /// final matrix = Matrix(/* ... */);
  ///
  /// // For display (forCode = false):
  /// print(matrix.gridToString());
  /// // Output:
  /// // #.#
  /// // .#.
  /// // #.#
  ///
  /// // For code (forCode = true):
  /// print(matrix.gridToString(forCode: true));
  /// // Output:
  /// // "#.#",
  /// // ".#.",
  /// // "#.#"
  /// ```
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
    final Matrix inputGrid,
    final Matrix templateGrid,
  ) {
    int matchingPixels = 0;
    int totalPixels = 0;

    for (int y = 0; y < inputGrid.rows; y++) {
      for (int x = 0; x < inputGrid.cols; x++) {
        if (inputGrid._data[y][x] || templateGrid._data[y][x]) {
          totalPixels++;
          if (inputGrid._data[y][x] == templateGrid._data[y][x]) {
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
    if (ar < 0.09 || ar > 50) {
      return true;
    }
    return false;
  }

  /// The grid contains one or more True values
  bool get isEmpty => _getContentSize().isEmpty;

  /// All entries in the grid are false
  bool get isNotEmpty => !isEmpty;

  /// smaller (~30%) in height artifacts will be considered punctuation
  bool isPunctuation() {
    // Calculate the height of the content
    final Size size = _getContentSize();

    // If there's no content, it's not punctuation
    if (size == Size.zero) {
      return false;
    }

    // Check if the content height is less than 40% of the total height
    return size.height < (rows * 0.40);
  }

  /// Ensure that x & y are in the boundary of the grid
  bool _isValidXY(final int x, final int y) {
    return (x >= 0 && x < cols) && (y >= 0 && y < rows);
  }

  /// Custom comparison method for matrices
  static bool matrixEquals(Matrix a, Matrix b) {
    // Check if dimensions are the same
    if (a.rows != b.rows || a.cols != b.cols) {
      return false;
    }

    // Compare each cell
    for (int y = 0; y < a.rows; y++) {
      for (int x = 0; x < a.cols; x++) {
        if (a._data[y][x] != b._data[y][x]) {
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
  ///   [grid] (```List<List<bool>>```): The 2D list of boolean values representing the grid.
  void setGrid(final List<List<bool>> grid) {
    if (grid.isEmpty || grid[0].isEmpty) {
      rows = 0;
      cols = 0;
      _data = [];
      return;
    }
    // Ensure all rows have the same length
    assert(
      _data.every((row) => row.length == cols),
      'All rows in the grid must have the same length',
    );

    rows = grid.length;
    cols = grid[0].length;

    // Create a deep copy of the grid
    // _data = grid;
    _data = List.generate(
      rows,
      (i) => List<bool>.from(grid[i]),
    );
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
  /// Example usage:
  ///   ```
  ///   Matrix matrix = Matrix(...);
  ///   Map<String, dynamic> jsonMap = matrix.toJson();
  ///   String jsonString = jsonEncode(jsonMap);
  ///   ```
  Map<String, dynamic> toJson() {
    return {
      'font': font,
      'rows': rows,
      'cols': cols,
      'data': _data.map((row) {
        return row.map((cell) => cell ? '#' : '.').join();
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
  /// This function analyzes a binary grid represented by [Matrix] to identify and count
  /// enclosed regions that meet specific criteria.
  ///
  /// Parameters:
  /// - [grid]: A [Matrix] object representing the binary grid to analyze.
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
  int _countEnclosedRegion(final Matrix grid) {
    final int rows = grid.rows;
    final int cols = grid.cols;

    final Matrix visited = Matrix(cols, rows);

    int loopCount = 0;
    int minRegionSize = 3; // Minimum size for a region to be considered a loop

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        if (!grid._data[y][x] && !visited._data[y][x]) {
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
    final Matrix grid,
    final Matrix visited,
    final int startX,
    final int startY,
  ) {
    int rows = grid.rows;
    int cols = grid.cols;
    Queue<List<int>> queue = Queue();
    queue.add([startX, startY]);
    visited._data[startY][startX] = true;
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
            !grid._data[newY][newX] &&
            !visited._data[newY][newX]) {
          queue.add([newX, newY]);
          visited._data[newY][newX] = true;
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
    final Matrix grid,
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
        if (!grid._data[newY][newX] && !visited.contains(key)) {
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
  bool _hasVerticalLineLeft(final Matrix matrix) {
    final Matrix visited = Matrix(matrix.cols, matrix.rows);

    // We only consider lines that are more than 40% of the character's height
    final int minVerticalLine =
        (matrix.rows * _thresholdLinePercentage).toInt();

    // Iterate over the matrix from left to right
    for (int x = 0; x < matrix.cols; x++) {
      for (int y = 0; y < matrix.rows; y++) {
        // If the current cell is filled and not visited
        if (matrix._data[y][x] && !visited._data[y][x]) {
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
  bool _hasVerticalLineRight(final Matrix matrix) {
    final Matrix visited = Matrix(matrix.cols, matrix.rows);

    // We only consider lines that are more than 40% of the character's height
    final int minVerticalLine =
        (matrix.rows * _thresholdLinePercentage).toInt();

    // Iterate over the matrix from right to left
    for (int x = matrix.cols - 1; x >= 0; x--) {
      for (int y = 0; y < matrix.rows; y++) {
        // If the current cell is filled and not visited
        if (matrix._data[y][x] && !visited._data[y][x]) {
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
    final Matrix matrix,
    final int x,
    int y,
    final Matrix visited,
  ) {
    final int rows = matrix.rows;
    int lineLength = 0;

    // Ensure no filled pixels on the immediate left side at any point
    while (y < rows && matrix._data[y][x]) {
      visited._data[y][x] = true;
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
    final Matrix matrix,
    final int x,
    int y,
    final Matrix visited,
  ) {
    final int rows = matrix.rows;
    int lineLength = 0;

    // Traverse downwards from the starting point
    while (y < rows && matrix._data[y][x]) {
      visited._data[y][x] = true;
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
    final Matrix m,
    final int x,
    final int y,
  ) {
    if (x - 1 < 0) {
      return true;
    }

    if (m.cellGet(x - 1, y) == false) {
      return true;
    }
    // if (m.cellGet(x - 2, y) == false) {
    //   return true;
    // }
    // if (m.cellGet(x - 3, y) == false) {
    //   return true;
    // }
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
    final Matrix m,
    final int x,
    final int y,
  ) {
    if (x + 1 >= m.cols) {
      return true;
    }

    if (m.cellGet(x + 1, y) == false) {
      return true;
    }
    // if (m.cellGet(x - 2, y) == false) {
    //   return true;
    // }
    // if (m.cellGet(x - 3, y) == false) {
    //   return true;
    // }
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
Future<ui.Image> imageToBlackOnWhite(
  final ui.Image inputImage,
) async {
  final int width = inputImage.width;
  final int height = inputImage.height;
  final Uint8List pixels = await imageToUint8List(inputImage);

  // Create a new Uint8List for the output image
  Uint8List outputPixels = Uint8List(pixels.length);
  for (int i = 0; i < pixels.length; i += 4) {
    final int r = pixels[i];
    final int g = pixels[i + 1];
    final int b = pixels[i + 2];
    // ignore: unused_local_variable
    final int a = pixels[i + 3];

    // Calculate brightness using a weighted average
    final int gray = (0.299 * r + 0.587 * g + 0.114 * b).toInt();

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

  // Convert Uint8List back to ui.Image
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

/// Converts a [ui.Image] to a [Uint8List] representation.
///
/// This function takes a [ui.Image] and converts it to a [Uint8List] containing
/// the raw RGBA data of the image.
///
/// Parameters:
/// - [image]: The source image to be converted. Can be null.
///
/// Returns:
/// A [Future] that resolves to a [Uint8List] containing the raw RGBA data of the image.
/// If the input [image] is null or conversion fails, returns an empty [Uint8List].
Future<Uint8List> imageToUint8List(final ui.Image? image) async {
  if (image == null) {
    return Uint8List(0);
  }
  final ByteData? data =
      await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data?.buffer.asUint8List() ?? Uint8List(0);
}

/// Performs an erosion operation on the input image.
///
/// This function takes a [ui.Image] and performs an erosion operation on it.
/// The erosion operation shrinks the black pixels (letters) against the white background.
///
/// Parameters:
/// - [inputImage]: The source image to be eroded (black and white).
/// - [kernelSize]: The size of the erosion kernel (must be an odd number).
///
/// Returns:
/// A [Future] that resolves to a [ui.Image] containing the eroded image.
Future<ui.Image> erode(
  final ui.Image inputImage, {
  final int kernelSize = 3,
}) async {
  final int width = inputImage.width;
  final int height = inputImage.height;

  // Get the pixel data from the input image
  final ByteData? byteData =
      await inputImage.toByteData(format: ui.ImageByteFormat.rawRgba);
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

  // Create a new ui.Image from the output pixels
  final ui.ImmutableBuffer buffer =
      await ui.ImmutableBuffer.fromUint8List(outputPixels);
  final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final ui.Codec codec = await descriptor.instantiateCodec();
  final ui.FrameInfo frameInfo = await codec.getNextFrame();
  return frameInfo.image;
}

/// Performs a dilation operation on the input image.
///
/// This function takes a [ui.Image] and performs a dilation operation on it.
/// The dilation operation expands the black pixels (letters) against the white background.
///
/// Parameters:
/// - [inputImage]: The source image to be dilated (black and white).
/// - [kernelSize]: The size of the dilation kernel (must be an odd number).
///
/// Returns:
/// A [Future] that resolves to a [ui.Image] containing the dilated image.
Future<ui.Image> dilate({
  required ui.Image inputImage,
  required int kernelSize,
}) async {
  final int width = inputImage.width;
  final int height = inputImage.height;

  // Get the pixel data from the input image
  final ByteData? byteData =
      await inputImage.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) {
    throw Exception('Failed to get image data');
  }
  final Uint8List inputPixels = byteData.buffer.asUint8List();

  // Create a new Uint8List for the output image
  final Uint8List outputPixels = Uint8List(width * height * 4);

  // Create the elliptical kernel
  final List<List<bool>> kernel = _createEllipticalKernel(kernelSize);

  // Apply dilation
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      bool hasBlackPixel = false;

      for (int ky = 0; ky < kernelSize; ky++) {
        for (int kx = 0; kx < kernelSize; kx++) {
          if (kernel[ky][kx]) {
            final int px = x + kx - kernelSize ~/ 2;
            final int py = y + ky - kernelSize ~/ 2;

            if (px >= 0 && px < width && py >= 0 && py < height) {
              final int index = (py * width + px) * 4;
              // Check if there's a black pixel in the kernel area
              if (inputPixels[index] == 0) {
                hasBlackPixel = true;
                break;
              }
            }
          }
        }
        if (hasBlackPixel) {
          break;
        }
      }

      final int outputIndex = (y * width + x) * 4;
      final int pixelValue = hasBlackPixel ? 0 : 255;
      outputPixels[outputIndex] = pixelValue; // R
      outputPixels[outputIndex + 1] = pixelValue; // G
      outputPixels[outputIndex + 2] = pixelValue; // B
      outputPixels[outputIndex + 3] = 255; // Alpha channel
    }
  }

  // Create a new ui.Image from the output pixels
  final ui.ImmutableBuffer buffer =
      await ui.ImmutableBuffer.fromUint8List(outputPixels);
  final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final ui.Codec codec = await descriptor.instantiateCodec();
  final ui.FrameInfo frameInfo = await codec.getNextFrame();
  return frameInfo.image;
}

/// Creates an elliptical kernel of the given size.
///
/// The kernel is a 2D list of booleans, where `true` values represent the
/// pixels that are part of the ellipse, and `false` values represent the
/// pixels that are outside the ellipse.
///
/// The ellipse is centered at the center of the kernel, and its major and
/// minor axes are equal to the size of the kernel.
///
/// Parameters:
/// [size]: The size of the kernel, which determines the size of the ellipse.
///
/// Returns:
/// A 2D list of booleans representing the elliptical kernel.
List<List<bool>> _createEllipticalKernel(final int size) {
  final List<List<bool>> kernel = List.generate(
    size,
    (_) => List.filled(size, false),
  );

  final double radiusX = size / 2;
  final double radiusY = size / 2;
  final double centerX = size / 2 - 0.5;
  final double centerY = size / 2 - 0.5;

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final double normalizedX = (x - centerX) / radiusX;
      final double normalizedY = (y - centerY) / radiusY;
      if (normalizedX * normalizedX + normalizedY * normalizedY <= 1) {
        kernel[y][x] = true;
      }
    }
  }

  return kernel;
}

/// Creates a new [ui.Image] from a [Uint8List] of pixel data.
///
/// This function takes a [Uint8List] containing the pixel data, the [width],
/// and the [height] of the image, and creates a new [ui.Image] from it.
///
/// Parameters:
/// - [pixels]: The [Uint8List] containing the pixel data.
/// - [width]: The width of the image.
/// - [height]: The height of the image.
///
/// Returns:
/// A [Future] that resolves to a [ui.Image] created from the pixel data.
Future<ui.Image> createImageFromPixels(
  final Uint8List pixels,
  final int width,
  final int height,
) async {
  // Create a new ui.Image from the modified pixels
  final ui.ImmutableBuffer buffer =
      await ui.ImmutableBuffer.fromUint8List(pixels);

  // Create a new ui.Image from the modified pixels
  final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final ui.Codec codec = await descriptor.instantiateCodec();
  final ui.FrameInfo frameInfo = await codec.getNextFrame();

  return frameInfo.image;
}

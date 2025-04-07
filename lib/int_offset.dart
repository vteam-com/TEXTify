/// This library is part of the Textify package.
/// Provides integer-based offset implementation for image processing operations.
library;

/// A 2D offset with integer coordinates.
///
/// This class represents a point in a 2D coordinate system using integer values.
/// It can be used to represent positions, translations, or any other 2D vector
/// with discrete coordinates.
class IntOffset {
  /// Creates an [IntOffset] with the given x and y coordinates.
  ///
  /// If no arguments are provided, creates an offset at the origin (0,0).
  ///
  /// * [x] - The x-coordinate of the offset (defaults to 0)
  /// * [y] - The y-coordinate of the offset (defaults to 0)
  const IntOffset([this.x = 0, this.y = 0]);

  /// The x-coordinate of the offset.
  final int x;

  /// The y-coordinate of the offset.
  final int y;

  /// Adds two [IntOffset]s and returns their sum as a new [IntOffset].
  ///
  /// The resulting offset has coordinates that are the sum of the coordinates
  /// of the two operands.
  IntOffset operator +(IntOffset other) => IntOffset(x + other.x, y + other.y);

  /// Subtracts one [IntOffset] from another and returns their difference.
  ///
  /// The resulting offset has coordinates that are the difference of the
  /// coordinates of the two operands.
  IntOffset operator -(IntOffset other) => IntOffset(x - other.x, y - other.y);

  /// Multiplies the offset by a scalar value.
  ///
  /// Returns a new [IntOffset] with coordinates multiplied by the given scalar.
  IntOffset operator *(int scalar) => IntOffset(x * scalar, y * scalar);

  /// Divides the offset by a scalar value using integer division.
  ///
  /// Returns a new [IntOffset] with coordinates divided by the given scalar
  /// using integer division.
  IntOffset operator ~/(int scalar) => IntOffset(x ~/ scalar, y ~/ scalar);

  /// Checks if this offset is equal to another object.
  ///
  /// Returns true if the other object is an [IntOffset] with the same coordinates.
  @override
  bool operator ==(Object other) =>
      other is IntOffset && x == other.x && y == other.y;

  /// Generates a hash code for this offset.
  ///
  /// The hash code is based on both x and y coordinates.
  @override
  int get hashCode => Object.hash(x, y);

  /// Returns a string representation of the offset.
  ///
  /// The format is 'x:{dx value} y:{dy value}'.
  @override
  String toString() => 'x:$x y:$y';

  /// Creates a new [IntOffset] translated by the given amounts.
  ///
  /// * [x] - The amount to translate in the x direction
  /// * [dy] - The amount to translate in the y direction
  ///
  /// Returns a new offset with coordinates shifted by the given amounts.
  IntOffset translate(int dx, int dy) => IntOffset(this.x + dx, this.y + dy);
}

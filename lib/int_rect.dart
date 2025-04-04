import 'dart:math';

import 'package:textify/int_offset.dart';

/// Exports
export 'package:textify/int_offset.dart';

/// A class representing a rectangle with integer coordinates and dimensions.
class IntRect {
  /// Creates a new [IntRect] with the specified position and dimensions.
  ///
  /// [left] The x-coordinate of the left edge.
  /// [top] The y-coordinate of the top edge.
  /// [width] The width of the rectangle.
  /// [height] The height of the rectangle.
  IntRect([this.left = 0, this.top = 0, this.width = 0, this.height = 0]);

  /// Creates a new [IntRect] from left, top, right, and bottom edges.
  ///
  /// [left] The x-coordinate of the left edge.
  /// [top] The y-coordinate of the top edge.
  /// [right] The x-coordinate of the right edge.
  /// [bottom] The y-coordinate of the bottom edge.
  factory IntRect.fromLTRB(
    final int left,
    final int top,
    final int right,
    final int bottom,
  ) {
    return IntRect(left, top, right - left, bottom - top);
  }

  /// Creates a new [IntRect] from left, top, width, and height values.
  ///
  /// [left] The x-coordinate of the left edge.
  /// [top] The y-coordinate of the top edge.
  /// [width] The width of the rectangle.
  /// [height] The height of the rectangle.
  factory IntRect.fromLTWH(
    final int left,
    final int top,
    final int width,
    final int height,
  ) {
    return IntRect(left, top, width, height);
  }

  /// Creates a new [IntRect] from center point, width, and height values.
  ///
  /// [center] The IntOffset of the center point.
  /// [width] The width of the rectangle.
  /// [height] The height of the rectangle.
  factory IntRect.fromCenter({
    required final IntOffset center,
    required final int width,
    required final int height,
  }) {
    return IntRect(
      center.x - width ~/ 2,
      center.y - height ~/ 2,
      width,
      height,
    );
  }

  /// Creates a new [IntRect] with zero position and dimensions.
  static final IntRect zero = IntRect(0, 0, 0, 0);

  /// The x-coordinate of the left edge of the rectangle.
  final int left;

  /// The y-coordinate of the top edge of the rectangle.
  final int top;

  /// The width of the rectangle.
  final int width;

  /// The height of the rectangle.
  final int height;

  /// The x-coordinate of the right edge of the rectangle.
  int get right => left + width;

  /// The y-coordinate of the bottom edge of the rectangle.
  int get bottom => top + height;

  /// The top-left corner of the rectangle.
  IntOffset get topLeft => IntOffset(left, top);

  /// The top-center point of the rectangle.
  IntOffset get topCenter => IntOffset(left + (width ~/ 2), top);

  /// The top-right corner of the rectangle.
  IntOffset get topRight => IntOffset(right, top);

  /// The center-left point of the rectangle.
  IntOffset get centerLeft => IntOffset(left, top + (height ~/ 2));

  /// The center point of the rectangle.
  IntOffset get center => IntOffset(left + (width ~/ 2), top + (height ~/ 2));

  /// The center-right point of the rectangle.
  IntOffset get centerRight => IntOffset(right, top + (height ~/ 2));

  /// The bottom-left corner of the rectangle.
  IntOffset get bottomLeft => IntOffset(left, bottom);

  /// The bottom-center point of the rectangle.
  IntOffset get bottomCenter => IntOffset(left + (width ~/ 2), bottom);

  /// The bottom-right corner of the rectangle.
  IntOffset get bottomRight => IntOffset(right, bottom);

  /// True if there is not size to this rect
  bool get isEmpty => width == 0 && height == 0;

  /// Checks if the given point (x, y) is contained within this rectangle.
  ///
  /// [x] The x-coordinate of the point to check.
  /// [y] The y-coordinate of the point to check.
  /// Returns true if the point is inside the rectangle, false otherwise.
  bool contains(final int x, final int y) {
    return x >= left && x < right && y >= top && y < bottom;
  }

  /// Checks if this rectangle intersects with another rectangle.
  ///
  /// [other] The other rectangle to check for intersection.
  /// Returns true if the rectangles intersect, false otherwise.
  bool intersects(final IntRect other) {
    if (intersectVertically(other) && intersectHorizontal(other)) {
      return true;
    }
    return false;
  }

  ///
  bool intersectVertically(final IntRect other) {
    if (other.top > bottom || other.bottom < top) {
      return false;
    }
    return true;
  }

  ///
  bool intersectHorizontal(final IntRect other) {
    if (other.left >= this.right || other.right <= this.left) {
      // off sides
      return false;
    }
    return true;
  }

  /// Creates a new rectangle shifted by the specified amounts.
  ///
  /// [dx] The amount to shift in the x direction.
  /// [dy] The amount to shift in the y direction.
  /// Returns a new [IntRect] with shifted coordinates.
  IntRect shift(final IntOffset offset) {
    return IntRect(left + offset.x, top + offset.y, width, height);
  }

  ///
  IntRect translate(final int dx, final int dy) {
    return IntRect(left + dx, top + dy, width, height);
  }

  /// Creates a new rectangle that includes both this rectangle and the input rectangle.
  ///
  /// [input] The rectangle to include.
  /// Returns a new [IntRect] that encompasses both rectangles.
  IntRect expandToInclude(final IntRect input) {
    final newLeft = left < input.left ? left : input.left;
    final newTop = top < input.top ? top : input.top;
    final newRight = right > input.right ? right : input.right;
    final newBottom = bottom > input.bottom ? bottom : input.bottom;
    return IntRect.fromLTRB(newLeft, newTop, newRight, newBottom);
  }

  /// Calculates the intersection of this rectangle with another rectangle.
  ///
  /// [other] The other rectangle to intersect with.
  /// Returns a new [IntRect] representing the intersection area.
  /// If there is no intersection, returns an empty rectangle (width and height of 0).
  IntRect intersect(final IntRect other) {
    final int newLeft = max(left, other.left);
    final int newTop = max(top, other.top);
    final int newRight = min(right, other.right);
    final int newBottom = min(bottom, other.bottom);

    // Check if there is a valid intersection
    if (newLeft >= newRight || newTop >= newBottom) {
      // No intersection, return empty rectangle
      return IntRect.zero;
    }

    return IntRect.fromLTRB(newLeft, newTop, newRight, newBottom);
  }

  @override
  String toString() =>
      'IntRect(L:$left, T:$top, R:$right B:$bottom W:$width, H:$height)';
}

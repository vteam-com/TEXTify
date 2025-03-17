///
class IntOffset {
  ///
  const IntOffset([this.dx = 0, this.dy = 0]);

  ///
  final int dx, dy;

  /// Adds two IntOffsets
  IntOffset operator +(IntOffset other) =>
      IntOffset(dx + other.dx, dy + other.dy);

  /// Subtracts two IntOffsets
  IntOffset operator -(IntOffset other) =>
      IntOffset(dx - other.dx, dy - other.dy);

  /// Multiply by a scalar value
  IntOffset operator *(int scalar) => IntOffset(dx * scalar, dy * scalar);

  /// Divide by a scalar value (integer division)
  IntOffset operator ~/(int scalar) => IntOffset(dx ~/ scalar, dy ~/ scalar);

  /// Checks equality
  @override
  bool operator ==(Object other) =>
      other is IntOffset && dx == other.dx && dy == other.dy;

  @override
  int get hashCode => Object.hash(dx, dy);

  @override
  String toString() => 'x:$dx y:$dy';

  /// Translates this offset by the given amounts
  IntOffset translate(int dx, int dy) => IntOffset(this.dx + dx, this.dy + dy);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:textify/int_offset.dart';

// Unit tests
void main() {
  group('IntOffset', () {
    test('constructor defaults to zero', () {
      final offset = IntOffset();
      expect(offset.dx, equals(0));
      expect(offset.dy, equals(0));
    });

    test('constructor with values', () {
      final offset = IntOffset(2, 3);
      expect(offset.dx, equals(2));
      expect(offset.dy, equals(3));
    });

    test('addition operator', () {
      final offset1 = IntOffset(1, 2);
      final offset2 = IntOffset(3, 4);
      final result = offset1 + offset2;
      expect(result.dx, equals(4));
      expect(result.dy, equals(6));
    });

    test('subtraction operator', () {
      final offset1 = IntOffset(5, 8);
      final offset2 = IntOffset(2, 3);
      final result = offset1 - offset2;
      expect(result.dx, equals(3));
      expect(result.dy, equals(5));
    });

    test('multiplication operator', () {
      final offset = IntOffset(2, 3);
      final result = offset * 3;
      expect(result.dx, equals(6));
      expect(result.dy, equals(9));
    });

    test('division operator', () {
      final offset = IntOffset(6, 9);
      final result = offset ~/ 3;
      expect(result.dx, equals(2));
      expect(result.dy, equals(3));
    });

    test('equality', () {
      final offset1 = IntOffset(1, 2);
      final offset2 = IntOffset(1, 2);
      final offset3 = IntOffset(2, 1);
      expect(offset1, equals(offset2));
      expect(offset1, isNot(equals(offset3)));
    });

    test('toString', () {
      final offset = IntOffset(1, 2);
      expect(offset.toString(), equals('x:1 y:2'));
    });

    test('translate', () {
      final offset = IntOffset(1, 2);
      final result = offset.translate(3, 4);
      expect(result.dx, equals(4));
      expect(result.dy, equals(6));
    });

    test('hashcode', () {
      final offset1 = IntOffset(1, 2);
      final offset2 = IntOffset(1, 2);
      final offset3 = IntOffset(2, 1);
      expect(offset1.hashCode, equals(offset2.hashCode));
      expect(offset1.hashCode, isNot(equals(offset3.hashCode)));
    });
  });
}

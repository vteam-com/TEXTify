import 'package:flutter_test/flutter_test.dart';
import 'package:textify/int_rect.dart';

void main() {
  group('IntOffset', () {
    test('constructor defaults to zero', () {
      final offset = IntOffset();
      expect(offset.x, equals(0));
      expect(offset.y, equals(0));
    });

    test('constructor with values', () {
      final offset = IntOffset(2, 3);
      expect(offset.x, equals(2));
      expect(offset.y, equals(3));
    });

    test('addition operator', () {
      final offset1 = IntOffset(1, 2);
      final offset2 = IntOffset(3, 4);
      final result = offset1 + offset2;
      expect(result.x, equals(4));
      expect(result.y, equals(6));
    });

    test('subtraction operator', () {
      final offset1 = IntOffset(5, 8);
      final offset2 = IntOffset(2, 3);
      final result = offset1 - offset2;
      expect(result.x, equals(3));
      expect(result.y, equals(5));
    });

    test('multiplication operator', () {
      final offset = IntOffset(2, 3);
      final result = offset * 3;
      expect(result.x, equals(6));
      expect(result.y, equals(9));
    });

    test('division operator', () {
      final offset = IntOffset(6, 9);
      final result = offset ~/ 3;
      expect(result.x, equals(2));
      expect(result.y, equals(3));
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
      expect(result.x, equals(4));
      expect(result.y, equals(6));
    });

    test('hashcode', () {
      final offset1 = IntOffset(1, 2);
      final offset2 = IntOffset(1, 2);
      final offset3 = IntOffset(2, 1);
      expect(offset1.hashCode, equals(offset2.hashCode));
      expect(offset1.hashCode, isNot(equals(offset3.hashCode)));
    });
  });
  group('IntRect', () {
    test('fromLTRB constructor creates correct rectangle', () {
      final rect = IntRect.fromLTRB(10, 20, 30, 40);
      expect(rect.left, equals(10));
      expect(rect.top, equals(20));
      expect(rect.width, equals(20));
      expect(rect.height, equals(20));
      expect(rect.right, equals(30));
      expect(rect.bottom, equals(40));
    });

    test('fromCenter constructor creates correct rectangle', () {
      final rect = IntRect.fromCenter(
        center: IntOffset(50, 50),
        width: 20,
        height: 30,
      );
      expect(rect.left, equals(40));
      expect(rect.top, equals(35));
      expect(rect.width, equals(20));
      expect(rect.height, equals(30));
      expect(rect.center, equals(IntOffset(50, 50)));
    });

    test('isEmpty returns correct value', () {
      expect(IntRect(0, 0, 0, 0).isEmpty, isTrue);
      expect(IntRect(0, 0, 1, 0).isEmpty, isFalse);
      expect(IntRect(0, 0, 0, 1).isEmpty, isFalse);
    });

    test('corner and center points are calculated correctly', () {
      final rect = IntRect(10, 20, 30, 40);
      expect(rect.topLeft, equals(IntOffset(10, 20)));
      expect(rect.topCenter, equals(IntOffset(25, 20)));
      expect(rect.topRight, equals(IntOffset(40, 20)));
      expect(rect.centerLeft, equals(IntOffset(10, 40)));
      expect(rect.center, equals(IntOffset(25, 40)));
      expect(rect.centerRight, equals(IntOffset(40, 40)));
      expect(rect.bottomLeft, equals(IntOffset(10, 60)));
      expect(rect.bottomCenter, equals(IntOffset(25, 60)));
      expect(rect.bottomRight, equals(IntOffset(40, 60)));
    });

    test('contains correctly identifies points inside and outside', () {
      final rect = IntRect(10, 10, 20, 20);
      expect(rect.contains(10, 10), isTrue);
      expect(rect.contains(29, 29), isTrue);
      expect(rect.contains(30, 30), isFalse);
      expect(rect.contains(9, 10), isFalse);
      expect(rect.contains(10, 9), isFalse);
    });

    test('intersects correctly identifies overlapping rectangles', () {
      final rect = IntRect(10, 10, 20, 20);
      expect(rect.intersects(IntRect(15, 15, 10, 10)), isTrue);
      expect(rect.intersects(IntRect(0, 0, 15, 15)), isTrue);
      expect(rect.intersects(IntRect(30, 30, 10, 10)), isFalse);
      expect(rect.intersects(IntRect(0, 0, 5, 5)), isFalse);
    });

    test('shift creates correctly translated rectangle', () {
      final rect = IntRect(10, 10, 20, 20);
      final shifted = rect.shift(IntOffset(5, -5));
      expect(shifted.left, equals(15));
      expect(shifted.top, equals(5));
      expect(shifted.width, equals(20));
      expect(shifted.height, equals(20));
    });

    test('translate creates correctly moved rectangle', () {
      final rect = IntRect(10, 10, 20, 20);
      final translated = rect.translate(-5, 5);
      expect(translated.left, equals(5));
      expect(translated.top, equals(15));
      expect(translated.width, equals(20));
      expect(translated.height, equals(20));
    });

    test('expandToInclude creates correct bounding rectangle', () {
      final rect1 = IntRect(10, 10, 20, 20);
      final rect2 = IntRect(25, 25, 10, 10);
      final expanded = rect1.expandToInclude(rect2);
      expect(expanded.left, equals(10));
      expect(expanded.top, equals(10));
      expect(expanded.right, equals(35));
      expect(expanded.bottom, equals(35));
    });

    test('toString returns correct string representation', () {
      final rect = IntRect(10, 20, 30, 40);
      expect(
        rect.toString(),
        equals('IntRect(L:10, T:20, R:40 B:60 W:30, H:40)'),
      );
    });

    test('zero creates rectangle with zero position and dimensions', () {
      final zeroRect = IntRect.zero;
      expect(zeroRect.left, equals(0));
      expect(zeroRect.top, equals(0));
      expect(zeroRect.width, equals(0));
      expect(zeroRect.height, equals(0));
      expect(zeroRect.isEmpty, isTrue);
    });

    test('intersect method returns correct intersection rectangle', () {
      final rect1 = IntRect(10, 10, 20, 20);
      final rect2 = IntRect(20, 20, 20, 20);
      final intersection = rect1.intersect(rect2);

      expect(intersection.left, equals(20));
      expect(intersection.top, equals(20));
      expect(intersection.width, equals(10));
      expect(intersection.height, equals(10));
      expect(intersection.right, equals(30));
      expect(intersection.bottom, equals(30));
    });

    test('intersect method returns zero rect when no intersection', () {
      final rect1 = IntRect(10, 10, 20, 20);
      final rect2 = IntRect(40, 40, 10, 10);
      final intersection = rect1.intersect(rect2);

      expect(intersection, equals(IntRect.zero));
      expect(intersection.isEmpty, isTrue);
    });

    test('fromLTWH factory creates correct rectangle', () {
      final rect = IntRect.fromLTWH(10, 20, 30, 40);

      expect(rect.left, equals(10));
      expect(rect.top, equals(20));
      expect(rect.width, equals(30));
      expect(rect.height, equals(40));
      expect(rect.right, equals(40));
      expect(rect.bottom, equals(60));
    });
  });
}

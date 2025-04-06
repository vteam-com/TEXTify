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
    test('default constructor initializes with zeros', () {
      final rect = IntRect();
      expect(rect.left, equals(0));
      expect(rect.top, equals(0));
      expect(rect.width, equals(0));
      expect(rect.height, equals(0));
    });

    test('constructor with values', () {
      final rect = IntRect(10, 20, 30, 40);
      expect(rect.left, equals(10));
      expect(rect.top, equals(20));
      expect(rect.width, equals(30));
      expect(rect.height, equals(40));
    });

    test('fromLTRB factory constructor', () {
      final rect = IntRect.fromLTRB(10, 20, 40, 60);
      expect(rect.left, equals(10));
      expect(rect.top, equals(20));
      expect(rect.width, equals(30));
      expect(rect.height, equals(40));
      expect(rect.right, equals(40));
      expect(rect.bottom, equals(60));
    });

    test('fromLTWH factory constructor', () {
      final rect = IntRect.fromLTWH(10, 20, 30, 40);
      expect(rect.left, equals(10));
      expect(rect.top, equals(20));
      expect(rect.width, equals(30));
      expect(rect.height, equals(40));
    });

    test('fromCenter factory constructor', () {
      final rect = IntRect.fromCenter(
        center: IntOffset(50, 60),
        width: 30,
        height: 40,
      );
      expect(rect.left, equals(35));
      expect(rect.top, equals(40));
      expect(rect.width, equals(30));
      expect(rect.height, equals(40));
      expect(rect.center.x, equals(50));
      expect(rect.center.y, equals(60));
    });

    test('zero static field', () {
      expect(IntRect.zero.left, equals(0));
      expect(IntRect.zero.top, equals(0));
      expect(IntRect.zero.width, equals(0));
      expect(IntRect.zero.height, equals(0));
    });

    test('computed properties', () {
      final rect = IntRect(10, 20, 30, 40);
      expect(rect.right, equals(40));
      expect(rect.bottom, equals(60));
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

    test('isEmpty property', () {
      expect(IntRect(0, 0, 0, 0).isEmpty, isTrue);
      expect(IntRect(10, 20, 0, 0).isEmpty, isTrue);
      expect(IntRect(10, 20, 30, 0).isEmpty, isFalse);
      expect(IntRect(10, 20, 0, 40).isEmpty, isFalse);
      expect(IntRect(10, 20, 30, 40).isEmpty, isFalse);
    });

    test('contains method', () {
      final rect = IntRect(10, 20, 30, 40);
      expect(rect.contains(10, 20), isTrue);
      expect(rect.contains(39, 59), isTrue);
      expect(rect.contains(25, 40), isTrue);
      expect(rect.contains(9, 20), isFalse);
      expect(rect.contains(10, 19), isFalse);
      expect(rect.contains(40, 20), isFalse);
      expect(rect.contains(10, 60), isFalse);
    });

    test('containsOffset method', () {
      final rect = IntRect(10, 20, 30, 40);
      expect(rect.containsOffset(IntOffset(10, 20)), isTrue);
      expect(rect.containsOffset(IntOffset(39, 59)), isTrue);
      expect(rect.containsOffset(IntOffset(25, 40)), isTrue);
      expect(rect.containsOffset(IntOffset(9, 20)), isFalse);
      expect(rect.containsOffset(IntOffset(40, 20)), isFalse);
    });

    test('containsRect method', () {
      final rect = IntRect(10, 20, 30, 40);
      expect(rect.containsRect(IntRect(15, 25, 10, 10)), isTrue);
      expect(rect.containsRect(IntRect(10, 20, 30, 40)), isTrue);
      expect(rect.containsRect(IntRect(5, 20, 10, 10)), isFalse);
      expect(rect.containsRect(IntRect(10, 15, 10, 10)), isFalse);
      expect(rect.containsRect(IntRect(30, 20, 20, 10)), isFalse);
      expect(rect.containsRect(IntRect(10, 50, 10, 20)), isFalse);
    });

    test('intersects method', () {
      final rect = IntRect(10, 20, 30, 40);
      expect(rect.intersects(IntRect(15, 25, 10, 10)), isTrue);
      expect(rect.intersects(IntRect(5, 15, 10, 10)), isTrue);
      expect(rect.intersects(IntRect(35, 55, 10, 10)), isTrue);
      expect(rect.intersects(IntRect(0, 0, 5, 5)), isFalse);
      expect(rect.intersects(IntRect(45, 25, 10, 10)), isFalse);
      expect(rect.intersects(IntRect(15, 65, 10, 10)), isFalse);
    });

    test('shift method', () {
      final rect = IntRect(10, 20, 30, 40);
      final shifted = rect.shift(IntOffset(5, -5));
      expect(shifted.left, equals(15));
      expect(shifted.top, equals(15));
      expect(shifted.width, equals(30));
      expect(shifted.height, equals(40));
    });

    test('translate method', () {
      final rect = IntRect(10, 20, 30, 40);
      final translated = rect.translate(5, -5);
      expect(translated.left, equals(15));
      expect(translated.top, equals(15));
      expect(translated.width, equals(30));
      expect(translated.height, equals(40));
    });

    test('expandToInclude method', () {
      final rect1 = IntRect(10, 20, 30, 40);
      final rect2 = IntRect(5, 15, 20, 20);
      final expanded = rect1.expandToInclude(rect2);
      expect(expanded.left, equals(5));
      expect(expanded.top, equals(15));
      expect(expanded.right, equals(40));
      expect(expanded.bottom, equals(60));
    });

    test('intersect method with overlap', () {
      final rect1 = IntRect(10, 20, 30, 40);
      final rect2 = IntRect(20, 30, 30, 40);
      final intersection = rect1.intersect(rect2);
      expect(intersection.left, equals(20));
      expect(intersection.top, equals(30));
      expect(intersection.width, equals(20));
      expect(intersection.height, equals(30));
    });

    test('intersect method with no overlap', () {
      final rect1 = IntRect(10, 20, 30, 40);
      final rect2 = IntRect(50, 70, 10, 10);
      final intersection = rect1.intersect(rect2);
      expect(intersection, equals(IntRect.zero));
    });

    test('toString method', () {
      final rect = IntRect(10, 20, 30, 40);
      expect(
        rect.toString(),
        equals('IntRect(L:10, T:20, R:40 B:60 W:30, H:40)'),
      );
    });
  });
}

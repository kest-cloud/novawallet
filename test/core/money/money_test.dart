import 'package:flutter_test/flutter_test.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';

void main() {
  group('Money Value Object Tests', () {
    group('Instantiation & Factory Constructors', () {
      test('fromKobo correctly stores raw kobo integer', () {
        const money = Money.fromKobo(15050);
        expect(money.kobo, equals(15050));
      });

      test('fromNaira calculates correct kobo value for positive amounts', () {
        final money = Money.fromNaira(250, 75);
        expect(money.kobo, equals(25075));
      });

      test(
        'fromNaira with default 0 kobo creates exact whole Naira amount',
        () {
          final money = Money.fromNaira(1000);
          expect(money.kobo, equals(100000));
        },
      );

      test('fromNaira correctly handles negative naira and kobo', () {
        final money = Money.fromNaira(-50, 25);
        expect(money.kobo, equals(-5025));
      });

      test('Money.zero creates 0 kobo instance', () {
        expect(Money.zero.kobo, equals(0));
        expect(Money.zero.isZero, isTrue);
      });

      test('fromNaira throws ArgumentError if kobo is outside 0..99', () {
        expect(() => Money.fromNaira(100, 100), throwsArgumentError);
        expect(() => Money.fromNaira(100, -1), throwsArgumentError);
      });
    });

    group('Zero Precision Loss in Arithmetic', () {
      test(
        'Proves no precision loss in 0.1 + 0.2 Naira equivalent addition',
        () {
          // In IEEE 754 floating point: 0.1 + 0.2 = 0.30000000000000004
          // With Money value object in Kobo: 10 kobo + 20 kobo = exactly 30 kobo
          const tenKobo = Money.fromKobo(10); // ₦0.10
          const twentyKobo = Money.fromKobo(20); // ₦0.20
          final sum = tenKobo + twentyKobo;

          expect(sum.kobo, equals(30));
          expect(sum.formatToNaira(), equals('₦0.30'));
        },
      );

      test(
        'Addition of multiple small fractions maintains exact cents/kobo',
        () {
          Money accumulator = Money.zero;
          // Add ₦0.07 (7 kobo) 100 times: 7 * 100 = 700 kobo (₦7.00)
          for (int i = 0; i < 100; i++) {
            accumulator = accumulator + const Money.fromKobo(7);
          }
          expect(accumulator.kobo, equals(700));
          expect(accumulator.formatToNaira(), equals('₦7.00'));
        },
      );

      test('Subtraction preserves exact precision down to single kobo', () {
        const initial = Money.fromKobo(100000); // ₦1,000.00
        const deducted = Money.fromKobo(99999); // ₦999.99
        final remainder = initial - deducted;

        expect(remainder.kobo, equals(1));
        expect(remainder.formatToNaira(), equals('₦0.01'));
      });

      test('Unary negation and absolute value', () {
        const positive = Money.fromKobo(5000);
        final negated = -positive;
        expect(negated.kobo, equals(-5000));
        expect(negated.abs().kobo, equals(5000));
      });

      test('Integer multiplication and division', () {
        const base = Money.fromKobo(250);
        final multiplied = base * 4;
        expect(multiplied.kobo, equals(1000));

        final divided = multiplied ~/ 3;
        expect(divided.kobo, equals(333)); // Exact integer floor division
      });
    });

    group('Comparison Operators', () {
      test('equality, <, <=, >, >= operators work accurately', () {
        const smaller = Money.fromKobo(5000);
        const larger = Money.fromKobo(10000);
        const equalToSmaller = Money.fromKobo(5000);

        expect(smaller == equalToSmaller, isTrue);
        expect(smaller == larger, isFalse);

        expect(smaller < larger, isTrue);
        expect(smaller <= larger, isTrue);
        expect(smaller <= equalToSmaller, isTrue);

        expect(larger > smaller, isTrue);
        expect(larger >= smaller, isTrue);
        expect(smaller >= equalToSmaller, isTrue);
        expect(smaller > larger, isFalse);
      });

      test('Comparable interface sort order', () {
        final list = [
          const Money.fromKobo(300),
          const Money.fromKobo(100),
          const Money.fromKobo(500),
          const Money.fromKobo(-200),
        ];

        list.sort();

        expect(
          list,
          equals([
            const Money.fromKobo(-200),
            const Money.fromKobo(100),
            const Money.fromKobo(300),
            const Money.fromKobo(500),
          ]),
        );
      });
    });

    group('formatToNaira Presentation Formatting', () {
      test('formats standard positive amount with symbol and kobo', () {
        const money = Money.fromKobo(125050050); // ₦1,250,500.50
        expect(money.formatToNaira(), equals('₦1,250,500.50'));
      });

      test('formats zero correctly', () {
        expect(Money.zero.formatToNaira(), equals('₦0.00'));
      });

      test('formats single digit kobo with leading zero', () {
        const money = Money.fromKobo(505); // ₦5.05
        expect(money.formatToNaira(), equals('₦5.05'));
      });

      test('formats negative amount correctly', () {
        const money = Money.fromKobo(-150075); // -₦1,500.75
        expect(money.formatToNaira(), equals('-₦1,500.75'));
      });

      test('respects showKobo = false option', () {
        const money = Money.fromKobo(125050050);
        expect(money.formatToNaira(showKobo: false), equals('₦1,250,500'));
      });

      test('respects includeSymbol = false option', () {
        const money = Money.fromKobo(125050050);
        expect(
          money.formatToNaira(includeSymbol: false),
          equals('1,250,500.50'),
        );
      });
    });
  });
}

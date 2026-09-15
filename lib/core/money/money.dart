import 'package:flutter/foundation.dart';

/// Money Value Object wrapping [kobo] as a pure 64-bit integer.
///
/// CRITICAL: To prevent precision loss inherent in floating-point representations,
/// no double/float types are used in storage or arithmetic calculations.
/// All internal amounts are represented in Kobo (1 Naira = 100 Kobo).
@immutable
class Money implements Comparable<Money> {
  /// The underlying monetary value in kobo (1/100th of a Naira).
  final int kobo;

  /// Private constructor enforcing integer representation.
  const Money._(this.kobo);

  /// Creates a [Money] instance from an amount in [kobo].
  const Money.fromKobo(int kobo) : this._(kobo);

  /// Creates a [Money] instance from integer [naira] and optional [kobo].
  ///
  /// Examples:
  /// - `Money.fromNaira(150, 50)` -> 15,050 kobo (₦150.50)
  /// - `Money.fromNaira(-50, 25)` -> -5,025 kobo (-₦50.25)
  factory Money.fromNaira(int naira, [int kobo = 0]) {
    if (kobo < 0 || kobo >= 100) {
      throw ArgumentError.value(
        kobo,
        'kobo',
        'Kobo must be an integer between 0 and 99',
      );
    }
    if (naira < 0) {
      return Money._((naira * 100) - kobo);
    }
    return Money._((naira * 100) + kobo);
  }

  /// Canonical zero monetary value.
  static const Money zero = Money._(0);

  /// Returns true if this amount is zero.
  bool get isZero => kobo == 0;

  /// Returns true if this amount is strictly positive (> 0).
  bool get isPositive => kobo > 0;

  /// Returns true if this amount is strictly negative (< 0).
  bool get isNegative => kobo < 0;

  /// Returns the absolute value of this [Money].
  Money abs() => Money._(kobo.abs());

  /// Returns the negated value of this [Money].
  Money operator -() => Money._(-kobo);

  /// Adds two [Money] objects using exact integer arithmetic.
  Money operator +(Money other) => Money._(kobo + other.kobo);

  /// Subtracts another [Money] object using exact integer arithmetic.
  Money operator -(Money other) => Money._(kobo - other.kobo);

  /// Multiplies this [Money] by an integer [factor].
  Money operator *(int factor) => Money._(kobo * factor);

  /// Integer-divides this [Money] by an integer [divisor].
  Money operator ~/(int divisor) {
    if (divisor == 0) {
      throw UnsupportedError('Integer division by zero');
    }
    return Money._(kobo ~/ divisor);
  }

  /// Relational comparison operators.
  bool operator <(Money other) => kobo < other.kobo;
  bool operator <=(Money other) => kobo <= other.kobo;
  bool operator >(Money other) => kobo > other.kobo;
  bool operator >=(Money other) => kobo >= other.kobo;

  @override
  int compareTo(Money other) => kobo.compareTo(other.kobo);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Money && other.kobo == kobo);

  @override
  int get hashCode => kobo.hashCode;

  /// Formats the monetary value into standard Naira representation.
  ///
  /// NOTE: This method is intended strictly for the presentation layer.
  /// No floating point math is performed; formatting is computed via integer
  /// extraction and string manipulation.
  ///
  /// Examples:
  /// - `1250500 kobo` -> `"₦12,505.00"`
  /// - `-50025 kobo` -> `"-₦500.25"`
  /// - `showKobo: false` -> `"₦12,505"`
  /// - `includeSymbol: false` -> `"12,505.00"`
  String formatToNaira({
    bool includeSymbol = true,
    bool showKobo = true,
    String symbol = '₦',
    bool spaceAfterSymbol = false,
  }) {
    final isNeg = kobo < 0;
    final absKobo = kobo.abs();
    final nairaPart = absKobo ~/ 100;
    final koboPart = absKobo % 100;

    final formattedNaira = _formatWithThousandSeparators(nairaPart);
    final formattedKobo = koboPart.toString().padLeft(2, '0');

    final buffer = StringBuffer();
    if (isNeg) {
      buffer.write('-');
    }
    if (includeSymbol) {
      buffer.write(symbol);
      if (spaceAfterSymbol) {
        buffer.write(' ');
      }
    }
    buffer.write(formattedNaira);
    if (showKobo) {
      buffer.write('.');
      buffer.write(formattedKobo);
    }
    return buffer.toString();
  }

  /// Formats an integer with standard commas as thousands separators.
  static String _formatWithThousandSeparators(int value) {
    final str = value.toString();
    if (str.length <= 3) return str;

    final result = StringBuffer();
    final firstGroupLength = str.length % 3 == 0 ? 3 : str.length % 3;
    result.write(str.substring(0, firstGroupLength));

    for (int i = firstGroupLength; i < str.length; i += 3) {
      result.write(',');
      result.write(str.substring(i, i + 3));
    }
    return result.toString();
  }

  @override
  String toString() => formatToNaira();
}

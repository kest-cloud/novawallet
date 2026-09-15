import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'failures.dart';

/// Result type representing either a successful [Success] or a failed [Error].
///
/// Patterned after functional Either / Result monads.
@immutable
sealed class Result<T> extends Equatable {
  const Result();

  /// Creates a successful [Result] containing [data].
  const factory Result.success(T data) = Success<T>;

  /// Creates a failed [Result] containing a [Failure].
  const factory Result.error(Failure failure) = Error<T>;

  /// Returns true if this instance represents a successful outcome.
  bool get isSuccess => this is Success<T>;

  /// Returns true if this instance represents an error outcome.
  bool get isError => this is Error<T>;

  /// Extracts the data if successful, otherwise returns null.
  T? get dataOrNull => switch (this) {
        Success<T>(data: final data) => data,
        Error<T>() => null,
      };

  /// Extracts the failure if an error, otherwise returns null.
  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        Error<T>(failure: final failure) => failure,
      };

  /// Executes [onSuccess] if successful or [onError] if failed.
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(Failure failure) onError,
  }) {
    return switch (this) {
      Success<T>(data: final data) => onSuccess(data),
      Error<T>(failure: final failure) => onError(failure),
    };
  }
}

/// Represents a successful computation holding [data].
final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);

  @override
  List<Object?> get props => [data];
}

/// Represents a failed computation holding a [failure].
final class Error<T> extends Result<T> {
  final Failure failure;
  const Error(this.failure);

  @override
  List<Object?> get props => [failure];
}

import 'package:equatable/equatable.dart';

/// Base class for all domain failure types.
abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure({required this.message, this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

/// Server/API returned error or failure.
class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.statusCode,
  });
}

/// Cache / Local database failure.
class CacheFailure extends Failure {
  const CacheFailure({
    required super.message,
    super.statusCode,
  });
}

/// Network connectivity loss failure.
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No active internet connection. Operation queued if eligible.',
    super.statusCode,
  });
}

/// Secure Storage access or decryption failure.
class StorageFailure extends Failure {
  const StorageFailure({
    required super.message,
    super.statusCode,
  });
}

/// Input / Value validation failure.
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.statusCode,
  });
}

/// Offline synchronization or conflict failure.
class SyncFailure extends Failure {
  const SyncFailure({
    required super.message,
    super.statusCode,
  });
}

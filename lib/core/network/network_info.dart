import 'package:connectivity_plus/connectivity_plus.dart';

/// Contract for checking network connectivity state across the application.
abstract class NetworkInfo {
  /// Returns whether the device currently has an active network connection.
  Future<bool> get isConnected;

  /// Emits updates whenever the network connectivity status changes.
  Stream<bool> get onConnectivityChanged;
}

/// Implementation of [NetworkInfo] using [Connectivity].
class NetworkInfoImpl implements NetworkInfo {
  final Connectivity _connectivity;

  NetworkInfoImpl({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  @override
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return _hasValidConnection(results);
  }

  @override
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(_hasValidConnection);
  }

  bool _hasValidConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((result) => result != ConnectivityResult.none);
  }
}

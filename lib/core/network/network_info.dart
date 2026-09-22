import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Contract for checking network connectivity state across the application.
abstract class NetworkInfo {
  /// Returns whether the device currently has an active network connection with real internet access.
  Future<bool> get isConnected;

  /// Emits updates whenever the network connectivity status changes.
  Stream<bool> get onConnectivityChanged;
}

/// Implementation of [NetworkInfo] using [Connectivity] and real socket/DNS ping check.
class NetworkInfoImpl implements NetworkInfo {
  final Connectivity _connectivity;
  final String checkHost;

  NetworkInfoImpl({Connectivity? connectivity, this.checkHost = 'google.com'})
    : _connectivity = connectivity ?? Connectivity();

  @override
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    if (!_hasValidInterface(results)) {
      debugPrint(
        '[NetworkInfo] No active network interface (interface: $results)',
      );
      return false;
    }
    final hasInternet = await _hasInternetAccess();
    debugPrint(
      '[NetworkInfo] Interface: $results, Real Internet Reachability: $hasInternet',
    );
    return hasInternet;
  }

  @override
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.asyncMap((results) async {
      if (!_hasValidInterface(results)) {
        debugPrint(
          '[NetworkInfo] Connectivity changed -> OFFLINE (no interface: $results)',
        );
        return false;
      }
      final hasInternet = await _hasInternetAccess();
      debugPrint(
        '[NetworkInfo] Connectivity changed -> Interface: $results, Real Internet: $hasInternet',
      );
      return hasInternet;
    }).distinct();
  }

  bool _hasValidInterface(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<bool> _hasInternetAccess() async {
    try {
      final socketResults = await InternetAddress.lookup(
        checkHost,
      ).timeout(const Duration(milliseconds: 2000));
      return socketResults.isNotEmpty && socketResults[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}

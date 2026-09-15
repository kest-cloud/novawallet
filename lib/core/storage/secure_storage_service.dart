import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Contract for persistent encrypted key-value storage.
abstract class SecureStorageService {
  /// Reads a decrypted value for the given [key], or null if not found.
  Future<String?> read(String key);

  /// Encrypts and writes [value] associated with [key].
  Future<void> write({required String key, required String value});

  /// Deletes the entry for [key].
  Future<void> delete(String key);

  /// Deletes all entries stored securely.
  Future<void> deleteAll();

  /// Checks if a key exists in secure storage.
  Future<bool> containsKey(String key);
}

/// Implementation of [SecureStorageService] using [FlutterSecureStorage].
class SecureStorageServiceImpl implements SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageServiceImpl({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();

  @override
  Future<bool> containsKey(String key) => _storage.containsKey(key: key);
}

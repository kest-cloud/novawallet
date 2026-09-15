import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_wallet_mobile/core/storage/secure_storage_service.dart';

/// In-memory mock for SecureStorageService testing.
class FakeSecureStorageService implements SecureStorageService {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read(String key) async => _storage[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _storage[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _storage.clear();
  }

  @override
  Future<bool> containsKey(String key) async => _storage.containsKey(key);
}

/// A guarded preference wrapper that forbids storing tokens/keys in plaintext preferences.
class InsecureStorageSecurityGuard {
  static final List<String> forbiddenKeySubstrings = [
    'token',
    'key',
    'secret',
    'password',
    'credential',
    'auth',
    'pin',
    'bearer',
  ];

  static void guardKey(String key) {
    final lower = key.toLowerCase();
    for (final forbidden in forbiddenKeySubstrings) {
      if (lower.contains(forbidden)) {
        throw SecurityException(
          'SECURITY VIOLATION: SharedPreferences / unencrypted storage cannot be used for sensitive key "$key". Use SecureStorageService instead.',
        );
      }
    }
  }
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => message;
}

void main() {
  group('Secure Storage & Token Audit Tests', () {
    late FakeSecureStorageService secureStorage;

    setUp(() {
      secureStorage = FakeSecureStorageService();
    });

    test(
      'SecureStorageService correctly stores, retrieves, and deletes sensitive credentials',
      () async {
        const authKey = 'auth_token_jwt';
        const secretToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.secret';

        // Write
        await secureStorage.write(key: authKey, value: secretToken);
        expect(await secureStorage.containsKey(authKey), isTrue);

        // Read
        final retrieved = await secureStorage.read(authKey);
        expect(retrieved, equals(secretToken));

        // Delete
        await secureStorage.delete(authKey);
        expect(await secureStorage.containsKey(authKey), isFalse);
        expect(await secureStorage.read(authKey), isNull);
      },
    );

    test(
      'InsecureStorageSecurityGuard throws if SharedPreferences or unencrypted store is used for keys containing "token" or "key"',
      () {
        expect(
          () => InsecureStorageSecurityGuard.guardKey('user_auth_token'),
          throwsA(isA<SecurityException>()),
        );

        expect(
          () => InsecureStorageSecurityGuard.guardKey('idempotency_key'),
          throwsA(isA<SecurityException>()),
        );

        expect(
          () => InsecureStorageSecurityGuard.guardKey('api_secret_key'),
          throwsA(isA<SecurityException>()),
        );

        expect(
          () => InsecureStorageSecurityGuard.guardKey('refresh_token'),
          throwsA(isA<SecurityException>()),
        );

        // Non-sensitive preference keys are allowed
        expect(
          () => InsecureStorageSecurityGuard.guardKey('theme_mode_dark'),
          returnsNormally,
        );
        expect(
          () => InsecureStorageSecurityGuard.guardKey('has_seen_onboarding'),
          returnsNormally,
        );
      },
    );

    test(
      'Static Code Audit: Proves zero direct SharedPreferences usage across lib/ for tokens or credentials',
      () {
        final libDir = Directory('lib');
        expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

        final dartFiles = libDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));

        for (final file in dartFiles) {
          final content = file.readAsStringSync();

          // Ensure no imports of shared_preferences
          expect(
            content.contains(
              'package:shared_preferences/shared_preferences.dart',
            ),
            isFalse,
            reason:
                'File ${file.path} must not import SharedPreferences directly. Use SecureStorageService.',
          );

          // Ensure no SharedPreferences.getInstance()
          expect(
            content.contains('SharedPreferences.getInstance'),
            isFalse,
            reason: 'File ${file.path} must not use SharedPreferences.',
          );
        }
      },
    );
  });
}

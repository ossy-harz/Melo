import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageException implements Exception {
  const SecureStorageException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => 'SecureStorageException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Secure Keystore-backed storage for sensitive tokens, passwords, and auth cookies.
/// Backed by native Android KeyStore (AES-GCM with RSA-OAEP key wrapping) and iOS Keychain.
/// Replaces cleartext SharedPreferences to prevent credential leakage.
class SecureCredentialStore {
  SecureCredentialStore._({
    FlutterSecureStorage? storage,
    this._allowMemoryFallback = false,
  })  : _secureStorage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(resetOnError: true),
            );

  static SecureCredentialStore instance = SecureCredentialStore._();

  /// Creates a test instance with in-memory fallback enabled or a mock storage delegate.
  factory SecureCredentialStore.forTesting({
    FlutterSecureStorage? storage,
    bool allowMemoryFallback = true,
  }) =>
      SecureCredentialStore._(
        storage: storage,
        allowMemoryFallback: allowMemoryFallback,
      );

  final FlutterSecureStorage _secureStorage;
  final bool _allowMemoryFallback;
  final Map<String, String> _memoryCache = {};

  Future<void> write(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await delete(key);
      return;
    }
    try {
      await _secureStorage.write(key: key, value: value);
      _memoryCache[key] = value;
    } on MissingPluginException {
      // In host test runners where native platform channels are unbound,
      // store in memory cache so unit tests function without physical Keystore.
      _memoryCache[key] = value;
    } catch (e) {
      if (_allowMemoryFallback) {
        _memoryCache[key] = value;
        return;
      }
      throw SecureStorageException('Failed to write key "$key" to secure storage', e);
    }
  }

  Future<String?> read(String key) async {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    try {
      final val = await _secureStorage.read(key: key);
      if (val != null) {
        _memoryCache[key] = val;
        return val;
      }
    } on MissingPluginException {
      return _memoryCache[key];
    } catch (e) {
      if (!_allowMemoryFallback) {
        throw SecureStorageException('Failed to read key "$key" from secure storage', e);
      }
    }
    return _memoryCache[key];
  }

  Future<void> delete(String key) async {
    _memoryCache.remove(key);
    try {
      await _secureStorage.delete(key: key);
    } on MissingPluginException {
      // Host test runner environment
    } catch (e) {
      if (!_allowMemoryFallback) {
        throw SecureStorageException('Failed to delete key "$key" from secure storage', e);
      }
    }
  }

  /// Clears in-memory cache (useful for testing or session reset).
  void clearMemoryCache() {
    _memoryCache.clear();
  }
}

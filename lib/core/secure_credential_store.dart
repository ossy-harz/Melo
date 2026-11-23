import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Keystore-backed storage for sensitive tokens, passwords, and auth cookies.
/// Backed by native Android KeyStore (AES-GCM with RSA-OAEP key wrapping) and iOS Keychain.
/// Replaces cleartext SharedPreferences to prevent credential leakage.
class SecureCredentialStore {
  SecureCredentialStore._();
  static final SecureCredentialStore instance = SecureCredentialStore._();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );
  final Map<String, String> _memoryCache = {};

  Future<void> write(String key, String? value) async {
    if (value == null || value.trim().isEmpty) {
      await delete(key);
      return;
    }
    _memoryCache[key] = value.trim();
    try {
      await _secureStorage.write(key: key, value: value.trim());
    } catch (_) {
      // Graceful in-memory fallback for test runners or environments without Keystore
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
    } catch (_) {}
    return null;
  }

  Future<void> delete(String key) async {
    _memoryCache.remove(key);
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {}
  }
}

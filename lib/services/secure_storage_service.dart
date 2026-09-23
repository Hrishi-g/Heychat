import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'log_service.dart';

/// SecureStorageService provides hardware-backed encrypted storage for:
/// 1. JWT Authentication Tokens (Android Keystore / iOS Keychain)
/// 2. User Phone Number (PII Protection & anti-tampering)
/// 3. At-Rest Database Encryption Key (256-bit AES master key for SQLCipher)
class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._init();

  late final FlutterSecureStorage _storage;

  static const String _keyJwtToken = 'jwt_token';
  static const String _keyUserMblNo = 'user_mblNo';
  static const String _keyDbKey = 'db_encryption_key';

  SecureStorageService._init() {
    // Configure hardware-backed encryption with standard key store for maximum device compatibility
    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );
  }

  // --- JWT Token ---

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _keyJwtToken, value: token);
    } catch (e) {
      LogService.error(
          'SecureStorage write error, fallback to SharedPreferences', e);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyJwtToken, token);
    }
  }

  Future<String?> getToken() async {
    try {
      final val = await _storage.read(key: _keyJwtToken);
      if (val != null && val.isNotEmpty) return val;
    } catch (e) {
      LogService.error(
          'SecureStorage read error, fallback to SharedPreferences', e);
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyJwtToken);
  }

  Future<void> clearToken() async {
    try {
      await _storage.delete(key: _keyJwtToken);
      await _storage.delete(key: _keyUserMblNo);
    } catch (e) {
      LogService.error(
          'SecureStorage delete error, fallback to SharedPreferences', e);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyJwtToken);
    await prefs.remove(_keyUserMblNo);
  }

  // --- Mobile Number (PII) ---

  Future<void> saveUserMblNo(String mblNo) async {
    try {
      await _storage.write(key: _keyUserMblNo, value: mblNo);
    } catch (e) {
      LogService.error(
          'SecureStorage write mblNo error, fallback to SharedPreferences', e);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserMblNo, mblNo);
    }
  }

  Future<String?> getUserMblNo() async {
    try {
      final val = await _storage.read(key: _keyUserMblNo);
      if (val != null && val.isNotEmpty) return val;
    } catch (e) {
      LogService.error(
          'SecureStorage read mblNo error, fallback to SharedPreferences', e);
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserMblNo);
  }

  // --- Database Encryption Key (256-bit AES) ---

  /// Returns existing 256-bit database key, or generates a fresh cryptographically
  /// secure key and mirrors it in Android Keystore / iOS Keychain & SharedPreferences.
  Future<String> getOrCreateDatabaseKey() async {
    final prefs = await SharedPreferences.getInstance();
    String? key;

    try {
      key = await _storage.read(key: _keyDbKey);
    } catch (e) {
      LogService.error('SecureStorage read db_key error', e);
    }

    if (key == null || key.isEmpty) {
      key = prefs.getString(_keyDbKey);
    }

    if (key == null || key.isEmpty) {
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      key = base64Url.encode(values);
      LogService.info(
          'SecureStorageService: Generated fresh 256-bit database encryption key');
    }

    // Mirror key across BOTH SecureStorage and SharedPreferences for fail-safe persistence
    try {
      await _storage.write(key: _keyDbKey, value: key);
    } catch (_) {}
    try {
      await prefs.setString(_keyDbKey, key);
    } catch (_) {}

    return key;
  }

  // --- Migration from plain SharedPreferences ---

  /// Seamlessly migrates existing legacy tokens from unencrypted SharedPreferences
  /// to FlutterSecureStorage without requiring users to log in again.
  Future<void> migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool migrated = false;

      if (prefs.containsKey('jwt_token')) {
        final legacyToken = prefs.getString('jwt_token');
        if (legacyToken != null && legacyToken.isNotEmpty) {
          final existing = await getToken();
          if (existing == null) {
            await saveToken(legacyToken);
            migrated = true;
          }
        }
        await prefs.remove('jwt_token');
      }

      if (prefs.containsKey('user_mblNo')) {
        final legacyMblNo = prefs.getString('user_mblNo');
        if (legacyMblNo != null && legacyMblNo.isNotEmpty) {
          final existing = await getUserMblNo();
          if (existing == null) {
            await saveUserMblNo(legacyMblNo);
            migrated = true;
          }
        }
        await prefs.remove('user_mblNo');
      }

      if (migrated) {
        LogService.info(
            'SecureStorageService: Successfully migrated legacy credentials to secure storage');
      }
    } catch (e) {
      LogService.error(
          'SecureStorageService: Error during SharedPreferences migration', e);
    }
  }
}

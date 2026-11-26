import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal async string store (Android Keystore-backed in production).
abstract class KeyValueStore {
  /// Reads [key], or null.
  Future<String?> read(String key);

  /// Writes [value] under [key].
  Future<void> write(String key, String value);

  /// Removes [key].
  Future<void> delete(String key);
}

/// Production store on top of `flutter_secure_storage`.
class SecureKeyValueStore implements KeyValueStore {
  /// Creates the store.
  SecureKeyValueStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// In-memory store for tests.
class MemoryKeyValueStore implements KeyValueStore {
  /// Backing map (exposed so tests can simulate an app restart).
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}

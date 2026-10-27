import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keychain / Keystore (encrypted local storage on web). Used for anything
/// holding API keys, secrets or access tokens.
///
/// - iOS: readable only while the device is unlocked, never synced to
///   iCloud Keychain and never restored onto another device.
/// - Android: AES-GCM data encrypted with a hardware-backed Keystore key
///   (Android Auto Backup is disabled in the manifest so encrypted values are
///   never restored where the key doesn't exist).
/// - Web: WebCrypto AES-GCM, but the key sits in the same browser profile, so
///   this only protects against casual inspection.
class SecureStorageDataSource {
  SecureStorageDataSource([FlutterSecureStorage? storage]) : _storage = storage ?? _defaultStorage;

  static const _defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device, synchronizable: false),
    aOptions: AndroidOptions(),
  );

  final FlutterSecureStorage _storage;

  Future<Object?> readJson(String key) async {
    final raw = await _storage.read(key: key);
    return raw == null ? null : jsonDecode(raw);
  }

  Future<void> writeJson(String key, Object value) => _storage.write(key: key, value: jsonEncode(value));
}

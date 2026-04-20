// lib/core/utils/secure_storage.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fleet_tracker/core/constants/app_constants.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

class SecureStorage {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> saveToken(String token) async =>
      _storage.write(key: AppConstants.tokenKey, value: token);

  Future<String?> getToken() async =>
      _storage.read(key: AppConstants.tokenKey);

  Future<void> deleteToken() async =>
      _storage.delete(key: AppConstants.tokenKey);

  Future<void> saveUser(String userJson) async =>
      _storage.write(key: AppConstants.userKey, value: userJson);

  Future<String?> getUser() async =>
      _storage.read(key: AppConstants.userKey);

  Future<void> saveTenantSlug(String tenantSlug) async =>
      _storage.write(key: AppConstants.tenantSlugKey, value: tenantSlug);

  Future<String?> getTenantSlug() async =>
      _storage.read(key: AppConstants.tenantSlugKey);

  Future<void> deleteTenantSlug() async =>
      _storage.delete(key: AppConstants.tenantSlugKey);

  Future<void> clearAll() async => _storage.deleteAll();
}

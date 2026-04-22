// lib/data/repositories/auth_repository.dart
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:fleet_tracker/core/constants/app_constants.dart';
import 'package:fleet_tracker/core/network/api_failure.dart';
import 'package:fleet_tracker/core/utils/secure_storage.dart';
import 'package:fleet_tracker/data/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleet_tracker/core/network/dio_client.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(dioProvider), ref.read(secureStorageProvider));
});

class AuthRepository {
  final Dio _dio;
  final SecureStorage _storage;

  AuthRepository(this._dio, this._storage);

  Future<Either<AppFailure, AuthResponse>> login({
    required String email,
    required String password,
    String? tenantSlug,
  }) async {
    try {
      final normalizedTenantSlug = _normalizeTenantSlug(tenantSlug);
      await _saveTenantSlugIfPresent(normalizedTenantSlug);
      final response = await _dio.post('/auth/login', data: {
        'tenant_slug': normalizedTenantSlug,
        'email': email,
        'password': password,
      });
      final auth = AuthResponse.fromJson(response.data);
      await _storage.saveToken(auth.token);
      await _storage.saveUser(auth.user.toJsonString());
      await _saveTenantSlugIfPresent(auth.tenant?.slug ?? normalizedTenantSlug);
      return Right(auth);
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<Either<AppFailure, AuthResponse>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? tenantSlug,
  }) async {
    try {
      final normalizedTenantSlug = _normalizeTenantSlug(tenantSlug);
      await _saveTenantSlugIfPresent(normalizedTenantSlug);
      final response = await _dio.post('/auth/register', data: {
        'tenant_slug': normalizedTenantSlug,
        'tenant_name': normalizedTenantSlug,
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
      });
      final auth = AuthResponse.fromJson(response.data);
      await _storage.saveToken(auth.token);
      await _storage.saveUser(auth.user.toJsonString());
      await _saveTenantSlugIfPresent(auth.tenant?.slug ?? normalizedTenantSlug);
      return Right(auth);
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<Either<AppFailure, UserModel>> getMe() async {
    try {
      final response = await _dio.get('/auth/me');
      final user = UserModel.fromJson(response.data['user'] ?? response.data);
      return Right(user);
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<void> logout() async {
    final tenantSlug = await _storage.getTenantSlug();
    await _storage.clearAll();
    if (tenantSlug != null && tenantSlug.isNotEmpty) {
      await _storage.saveTenantSlug(tenantSlug);
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<UserModel?> getCachedUser() async {
    final json = await _storage.getUser();
    if (json == null) return null;
    try {
      return UserModel.fromJsonString(json);
    } catch (_) {
      return null;
    }
  }

  Future<String> getTenantSlug() async {
    final saved = await _storage.getTenantSlug();
    if (saved != null && saved.isNotEmpty) return saved;
    return AppConstants.defaultTenantSlug;
  }

  Future<void> _saveTenantSlugIfPresent(String? tenantSlug) async {
    final normalized = _normalizeTenantSlug(tenantSlug);
    if (normalized.isNotEmpty) {
      await _storage.saveTenantSlug(normalized);
    }
  }

  String _normalizeTenantSlug(String? tenantSlug) {
    return (tenantSlug ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9-]'), '');
  }
}

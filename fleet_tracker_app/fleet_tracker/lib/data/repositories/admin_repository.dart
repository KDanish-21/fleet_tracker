import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:fleet_tracker/core/network/api_failure.dart';
import 'package:fleet_tracker/core/network/dio_client.dart';
import 'package:fleet_tracker/data/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.read(dioProvider));
});

class AdminRepository {
  final Dio _dio;

  AdminRepository(this._dio);

  Future<Either<AppFailure, AdminStats>> getSuperadminStats() async {
    try {
      final response = await _dio.get('/superadmin/stats');
      return Right(AdminStats.fromJson(response.data));
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<Either<AppFailure, List<TenantModel>>> getTenants() async {
    try {
      final response = await _dio.get('/superadmin/tenants');
      final List raw = response.data['tenants'] ?? response.data ?? [];
      return Right(raw.map((t) => TenantModel.fromJson(t)).toList());
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<Either<AppFailure, TenantModel>> createTenant({
    required String slug,
    required String name,
    String currency = 'USD',
  }) async {
    try {
      final response = await _dio.post('/superadmin/tenants', data: {
        'slug': slug,
        'name': name,
        'currency': currency,
      });
      return Right(TenantModel.fromJson(response.data));
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<Either<AppFailure, TenantModel>> updateTenant({
    required String tenantId,
    String? name,
    String? currency,
    bool? isActive,
  }) async {
    try {
      final response = await _dio.put('/superadmin/tenants/$tenantId', data: {
        if (name != null) 'name': name,
        if (currency != null) 'currency': currency,
        if (isActive != null) 'is_active': isActive,
      });
      return Right(TenantModel.fromJson(response.data));
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<Either<AppFailure, void>> deleteTenant(String tenantId) async {
    try {
      await _dio.delete('/superadmin/tenants/$tenantId');
      return const Right(null);
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<Either<AppFailure, List<UserModel>>> getUsers({
    String? tenantId,
    bool superadmin = false,
  }) async {
    try {
      final path = superadmin && tenantId != null
          ? '/superadmin/tenants/$tenantId/users'
          : '/users/';
      final response = await _dio.get(path);
      final List raw = response.data['users'] ?? response.data ?? [];
      return Right(raw.map((u) => UserModel.fromJson(u)).toList());
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<Either<AppFailure, UserModel>> createUser({
    String? tenantId,
    bool superadmin = false,
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    try {
      final path = superadmin && tenantId != null
          ? '/superadmin/tenants/$tenantId/users'
          : '/users/invite';
      final response = await _dio.post(path, data: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role,
      });
      return Right(UserModel.fromJson(response.data['user'] ?? response.data));
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<Either<AppFailure, UserModel>> updateUserRole({
    String? tenantId,
    bool superadmin = false,
    required String userId,
    required String role,
  }) async {
    try {
      final path = superadmin && tenantId != null
          ? '/superadmin/tenants/$tenantId/users/$userId/role'
          : '/users/$userId/role';
      final response = await _dio.put(path, data: {'role': role});
      return Right(UserModel.fromJson(response.data['user'] ?? response.data));
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<Either<AppFailure, void>> deleteUser({
    String? tenantId,
    bool superadmin = false,
    required String userId,
  }) async {
    try {
      final path = superadmin && tenantId != null
          ? '/superadmin/tenants/$tenantId/users/$userId'
          : '/users/$userId';
      await _dio.delete(path);
      return const Right(null);
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<Either<AppFailure, List<TenantDeviceModel>>> getDevices({
    String? tenantId,
    bool superadmin = false,
  }) async {
    try {
      final path = superadmin && tenantId != null
          ? '/superadmin/tenants/$tenantId/devices'
          : '/tenants/devices';
      final response = await _dio.get(path);
      final List raw = response.data['devices'] ?? response.data ?? [];
      return Right(raw.map((d) => TenantDeviceModel.fromJson(d)).toList());
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<Either<AppFailure, void>> upsertDevice({
    String? tenantId,
    bool superadmin = false,
    required String deviceId,
    required String deviceName,
  }) async {
    try {
      final path = superadmin && tenantId != null
          ? '/superadmin/tenants/$tenantId/devices'
          : '/tenants/devices';
      await _dio.post(path, data: {
        'device_id': deviceId,
        'device_name': deviceName,
      });
      return const Right(null);
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<Either<AppFailure, void>> deleteDevice({
    String? tenantId,
    bool superadmin = false,
    required String deviceId,
  }) async {
    try {
      final path = superadmin && tenantId != null
          ? '/superadmin/tenants/$tenantId/devices/$deviceId'
          : '/tenants/devices/$deviceId';
      await _dio.delete(path);
      return const Right(null);
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }
}

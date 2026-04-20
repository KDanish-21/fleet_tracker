// lib/core/network/auth_interceptor.dart
import 'package:dio/dio.dart';
import 'package:fleet_tracker/core/constants/app_constants.dart';
import 'package:fleet_tracker/core/utils/secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final storage = _ref.read(secureStorageProvider);
    final token = await storage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    final tenantSlug = await storage.getTenantSlug();
    final effectiveTenantSlug = (tenantSlug != null && tenantSlug.isNotEmpty)
        ? tenantSlug
        : AppConstants.defaultTenantSlug;
    if (effectiveTenantSlug.isNotEmpty) {
      options.headers['x-tenant-slug'] = effectiveTenantSlug;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('DioError: ${err.message}');
    handler.next(err);
  }
}

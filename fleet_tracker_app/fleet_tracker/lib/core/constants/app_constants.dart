// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // API
  static const String baseUrl = 'https://fleet-tracker-5od4.onrender.com/api';
  static const String defaultTenantSlug = String.fromEnvironment('TENANT_SLUG', defaultValue: '');
  static const int connectTimeout = 90000;
  static const int receiveTimeout = 90000;
  static const int pollIntervalSeconds = 10;

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String tenantSlugKey = 'tenant_slug';

  // Route Names
  static const String splashRoute = '/';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String dashboardRoute = '/dashboard';
  static const String vehiclesRoute = '/vehicles';
  static const String mapRoute = '/map';
  static const String tripsRoute = '/reports/trips';
  static const String alarmsRoute = '/reports/alarms';
  static const String fuelRoute = '/reports/fuel';
  static const String profileRoute = '/profile';
}

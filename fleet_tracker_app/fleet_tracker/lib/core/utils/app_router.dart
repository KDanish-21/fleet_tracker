// lib/core/utils/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fleet_tracker/core/constants/app_constants.dart';
import 'package:fleet_tracker/data/repositories/auth_repository.dart';
import 'package:fleet_tracker/presentation/auth/login/login_screen.dart';
import 'package:fleet_tracker/presentation/auth/register/register_screen.dart';
import 'package:fleet_tracker/presentation/dashboard/dashboard_screen.dart';
import 'package:fleet_tracker/presentation/vehicles/vehicles_screen.dart';
import 'package:fleet_tracker/presentation/map/map_screen.dart';
import 'package:fleet_tracker/presentation/reports/trips/trips_screen.dart';
import 'package:fleet_tracker/presentation/reports/alarms/alarms_screen.dart';
import 'package:fleet_tracker/presentation/reports/fuel/fuel_screen.dart';
import 'package:fleet_tracker/presentation/admin/admin_screen.dart';
import 'package:fleet_tracker/presentation/profile/profile_screen.dart';
import 'package:fleet_tracker/presentation/splash_screen.dart';
import 'package:fleet_tracker/presentation/shell_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.read(authRepositoryProvider);

  return GoRouter(
    initialLocation: AppConstants.splashRoute,
    redirect: (context, state) async {
      final isLoggedIn = await authRepo.isLoggedIn();
      final isSplash = state.matchedLocation == AppConstants.splashRoute;
      final isAuthRoute = state.matchedLocation == AppConstants.loginRoute ||
          state.matchedLocation == AppConstants.registerRoute;

      // Let splash screen handle its own navigation
      if (isSplash) return null;

      // Not logged in trying to access protected route -> login
      if (!isLoggedIn && !isAuthRoute) return AppConstants.loginRoute;

      // Logged in trying to access auth routes -> dashboard
      if (isLoggedIn && isAuthRoute) return AppConstants.dashboardRoute;

      return null;
    },
    routes: [
      GoRoute(
        path: AppConstants.splashRoute,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppConstants.loginRoute,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppConstants.registerRoute,
        builder: (_, __) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: AppConstants.dashboardRoute,
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppConstants.vehiclesRoute,
            builder: (_, __) => const VehiclesScreen(),
          ),
          GoRoute(
            path: AppConstants.mapRoute,
            builder: (_, __) => const MapScreen(),
          ),
          GoRoute(
            path: AppConstants.tripsRoute,
            builder: (_, __) => const TripsScreen(),
          ),
          GoRoute(
            path: AppConstants.alarmsRoute,
            builder: (_, __) => const AlarmsScreen(),
          ),
          GoRoute(
            path: AppConstants.fuelRoute,
            builder: (_, __) => const FuelScreen(),
          ),
          GoRoute(
            path: AppConstants.adminRoute,
            builder: (_, __) => const AdminScreen(),
          ),
          GoRoute(
            path: AppConstants.profileRoute,
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
});

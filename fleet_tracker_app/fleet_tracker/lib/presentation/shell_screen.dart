// lib/presentation/shell_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fleet_tracker/core/constants/app_constants.dart';
import 'package:fleet_tracker/core/theme/app_theme.dart';
import 'package:fleet_tracker/data/models/models.dart';
import 'package:fleet_tracker/data/repositories/auth_repository.dart';

final _shellUserProvider = FutureProvider<UserModel?>((ref) async {
  return ref.read(authRepositoryProvider).getCachedUser();
});

class ShellScreen extends ConsumerWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  bool _canManage(String? role) {
    return role == 'owner' || role == 'admin' || role == 'superadmin';
  }

  int _currentIndex(BuildContext context, bool showAdmin, bool superadmin) {
    final location = GoRouterState.of(context).matchedLocation;
    if (superadmin) {
      if (location.startsWith(AppConstants.profileRoute)) {
        return 1;
      }
      return 0;
    }
    if (location.startsWith(AppConstants.dashboardRoute)) return 0;
    if (location.startsWith(AppConstants.mapRoute)) return 1;
    if (location.startsWith(AppConstants.vehiclesRoute)) return 2;
    if (location.startsWith('/reports')) return 3;
    if (showAdmin && location.startsWith(AppConstants.adminRoute)) return 4;
    if (location.startsWith(AppConstants.profileRoute)) {
      return showAdmin ? 5 : 4;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(_shellUserProvider).valueOrNull;
    final showAdmin = _canManage(user?.role);
    final superadmin = user?.role == 'superadmin';
    final idx = _currentIndex(context, showAdmin, superadmin);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.cardBorder, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: idx,
          onTap: (i) {
            if (superadmin) {
              switch (i) {
                case 0:
                  context.go(AppConstants.adminRoute);
                  break;
                case 1:
                  context.go(AppConstants.profileRoute);
                  break;
              }
              return;
            }
            switch (i) {
              case 0:
                context.go(AppConstants.dashboardRoute);
                break;
              case 1:
                context.go(AppConstants.mapRoute);
                break;
              case 2:
                context.go(AppConstants.vehiclesRoute);
                break;
              case 3:
                context.go(AppConstants.tripsRoute);
                break;
              case 4:
                context.go(showAdmin
                    ? AppConstants.adminRoute
                    : AppConstants.profileRoute);
                break;
              case 5:
                context.go(AppConstants.profileRoute);
                break;
            }
          },
          items: superadmin
              ? const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.admin_panel_settings_rounded),
                    label: 'Admin',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_rounded),
                    label: 'Profile',
                  ),
                ]
              : [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard_rounded),
                    label: 'Dashboard',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.map_rounded),
                    label: 'Live Map',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.local_shipping_rounded),
                    label: 'Vehicles',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.bar_chart_rounded),
                    label: 'Reports',
                  ),
                  if (showAdmin)
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.admin_panel_settings_rounded),
                      label: 'Admin',
                    ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.person_rounded),
                    label: 'Profile',
                  ),
                ],
        ),
      ),
    );
  }
}

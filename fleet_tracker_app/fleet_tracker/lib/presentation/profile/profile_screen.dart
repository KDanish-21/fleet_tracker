// lib/presentation/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fleet_tracker/core/constants/app_constants.dart';
import 'package:fleet_tracker/core/theme/app_theme.dart';
import 'package:fleet_tracker/data/models/models.dart';
import 'package:fleet_tracker/data/repositories/auth_repository.dart';
import 'package:fleet_tracker/presentation/widgets/app_widgets.dart';

final _profileProvider = FutureProvider<UserModel?>((ref) async {
  return ref.read(authRepositoryProvider).getCachedUser();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(_profileProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: userAsync.when(
          loading: () => const AppLoadingIndicator(),
          error: (_, __) => const ErrorView(message: 'Could not load profile'),
          data: (user) => ListView(
            padding: EdgeInsets.zero,
            children: [
              // ─── Dark Hero ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 70, 20, 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.heroFrom, AppColors.heroVia, Color(0xFF312e81)],
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          (user?.name.isNotEmpty ?? false)
                              ? user!.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(user?.name ?? '-',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        )),
                    const SizedBox(height: 4),
                    Text(user?.email ?? '-',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ),
              ),

              // ─── Body ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    // Account Details
                    _SectionCard(
                      title: 'ACCOUNT',
                      children: [
                        InfoRow(icon: Icons.person_outline_rounded, label: 'Name', value: user?.name ?? '-'),
                        const Divider(height: 1),
                        InfoRow(icon: Icons.verified_user_outlined, label: 'Role', value: user?.role ?? '-'),
                        const Divider(height: 1),
                        InfoRow(icon: Icons.email_outlined, label: 'Email', value: user?.email ?? '-'),
                        const Divider(height: 1),
                        InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: user?.phone ?? '-'),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // App Settings
                    _SectionCard(
                      title: 'NOTIFICATIONS',
                      children: [
                        _SettingsTile(
                          icon: Icons.notifications_outlined,
                          iconBg: AppColors.stoppedBg,
                          iconColor: AppColors.danger,
                          label: 'Alarm push alerts',
                          trailing: Switch(
                            value: true,
                            onChanged: (_) {},
                            activeColor: AppColors.primary,
                          ),
                        ),
                        const Divider(height: 1),
                        _SettingsTile(
                          icon: Icons.refresh_rounded,
                          iconBg: AppColors.movingBg,
                          iconColor: AppColors.success,
                          label: 'Live update interval',
                          trailing: Text(
                            '${AppConstants.pollIntervalSeconds}s',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // App info
                    _SectionCard(
                      title: 'APP',
                      children: [
                        _SettingsTile(
                          icon: Icons.cloud_outlined,
                          iconBg: AppColors.pageBg,
                          iconColor: AppColors.textSecondary,
                          label: 'Backend server',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.movingBg,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text('Connected',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF15803D),
                                )),
                          ),
                        ),
                        const Divider(height: 1),
                        InfoRow(icon: Icons.info_outline_rounded, label: 'Version', value: '1.0.0'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Logout
                    GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Sign Out'),
                            content: const Text('Are you sure you want to sign out?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                                child: const Text('Sign Out'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          await ref.read(authRepositoryProvider).logout();
                          context.go(AppConstants.loginRoute);
                        }
                      },
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.stoppedBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, size: 17, color: AppColors.danger),
                            SizedBox(width: 8),
                            Text('Sign Out',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.danger,
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('FleetTracker v1.0.0',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        )),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 0.08,
              )),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                )),
          ),
          trailing,
        ],
      ),
    );
  }
}

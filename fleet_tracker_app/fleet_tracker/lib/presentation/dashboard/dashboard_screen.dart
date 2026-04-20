// lib/presentation/dashboard/dashboard_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fleet_tracker/core/constants/app_constants.dart';
import 'package:fleet_tracker/core/theme/app_theme.dart';
import 'package:fleet_tracker/data/models/models.dart';
import 'package:fleet_tracker/data/repositories/auth_repository.dart';
import 'package:fleet_tracker/data/repositories/vehicle_repository.dart';
import 'package:fleet_tracker/presentation/widgets/app_widgets.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _positionsProvider = FutureProvider<List<PositionModel>>((ref) async {
  final repo = ref.read(vehicleRepositoryProvider);
  final result = await repo.getLivePositions();
  return result.fold((_) => [], (positions) => positions);
});

final _vehiclesProvider = FutureProvider<List<VehicleModel>>((ref) async {
  final repo = ref.read(vehicleRepositoryProvider);
  final result = await repo.getVehicles();
  return result.fold((_) => [], (v) => v);
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _timer;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _startPolling();
  }

  Future<void> _loadUser() async {
    final user = await ref.read(authRepositoryProvider).getCachedUser();
    if (mounted) setState(() => _user = user);
  }

  void _startPolling() {
    _timer = Timer.periodic(
      const Duration(seconds: AppConstants.pollIntervalSeconds),
      (_) => ref.invalidate(_positionsProvider),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posAsync = ref.watch(_positionsProvider);
    final vehAsync = ref.watch(_vehiclesProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(_positionsProvider);
            ref.invalidate(_vehiclesProvider);
          },
          child: CustomScrollView(
            slivers: [
              // ─── Dark Hero Header ──────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.heroFrom, AppColors.heroVia, Color(0xFF2d2b8a)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: Column(
                        children: [
                          // Top row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Good ${_greeting()},',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _user?.name ?? 'Fleet Manager',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    (_user?.name.isNotEmpty ?? false)
                                        ? _user!.name[0].toUpperCase()
                                        : 'A',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Live pill
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: AppColors.success.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('LIVE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.success,
                                        letterSpacing: 0.04,
                                      )),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Stats row
                          posAsync.when(
                            loading: () => _buildStatRow(0, 0, 0, 0),
                            error: (_, __) => _buildStatRow(0, 0, 0, 0),
                            data: (positions) {
                              final vehicles = vehAsync.valueOrNull ?? [];
                              final total = vehicles.isNotEmpty ? vehicles.length : positions.length;
                              final movingCount = positions.where((p) => p.isMoving).length;
                              final idleCount = positions.where((p) => !p.isMoving).length;
                              final offlineCount = total - positions.length;
                              return _buildStatRow(total, movingCount, idleCount, offlineCount);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ─── Quick Actions ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Quick Actions'),
                      Row(
                        children: [
                          _QuickAction(
                            icon: Icons.map_rounded,
                            label: 'Live Map',
                            color: AppColors.info,
                            onTap: () => context.go(AppConstants.mapRoute),
                          ),
                          const SizedBox(width: 10),
                          _QuickAction(
                            icon: Icons.route_rounded,
                            label: 'Trip Report',
                            color: AppColors.primary,
                            onTap: () => context.go(AppConstants.tripsRoute),
                          ),
                          const SizedBox(width: 10),
                          _QuickAction(
                            icon: Icons.warning_amber_rounded,
                            label: 'Alarms',
                            color: AppColors.warning,
                            onTap: () => context.go(AppConstants.alarmsRoute),
                          ),
                          const SizedBox(width: 10),
                          _QuickAction(
                            icon: Icons.local_gas_station_rounded,
                            label: 'Fuel',
                            color: AppColors.danger,
                            onTap: () => context.go(AppConstants.fuelRoute),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Recent Vehicles ──────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: SectionHeader(
                    title: 'All Vehicles',
                    action: 'View all',
                    onAction: () => context.go(AppConstants.vehiclesRoute),
                  ),
                ),
              ),

              posAsync.when(
                loading: () => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: ShimmerCard(height: 72),
                    ),
                    childCount: 3,
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: ErrorView(
                    message: 'Failed to load fleet data',
                    onRetry: () => ref.invalidate(_positionsProvider),
                  ),
                ),
                data: (positions) {
                  final recent = positions.take(5).toList();
                  if (recent.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: EmptyView(
                        message: 'No active vehicles right now',
                        icon: Icons.local_shipping_rounded,
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final p = recent[i];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: _ActivityTile(position: p),
                        );
                      },
                      childCount: recent.length,
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(int total, int moving, int idle, int offline) {
    return Row(
      children: [
        _StatPill(value: '$total', label: 'Total', color: Colors.white),
        const SizedBox(width: 8),
        _StatPill(value: '$moving', label: 'Moving', color: AppColors.success),
        const SizedBox(width: 8),
        _StatPill(value: '$idle', label: 'Idle', color: AppColors.warning),
        const SizedBox(width: 8),
        _StatPill(value: '$offline', label: 'Offline', color: AppColors.danger),
      ],
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}

// ─── Stat Pill ───────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatPill({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                )),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.45),
                  letterSpacing: 0.05,
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Action Button ───────────────────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Activity Tile ─────────────────────────────────────────────────────────────
class _ActivityTile extends StatelessWidget {
  final PositionModel position;
  const _ActivityTile({required this.position});

  @override
  Widget build(BuildContext context) {
    final isMoving = position.isMoving;
    final statusColor = isMoving ? AppColors.moving : AppColors.idle;
    final statusBg = isMoving ? AppColors.movingBg : AppColors.idleBg;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isMoving ? Icons.directions_car_rounded : Icons.pause_rounded,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  position.vehicleName ?? 'Device ${position.deviceId}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${position.speed?.toStringAsFixed(0) ?? '0'} km/h  ·  ${position.timeAgoText.isNotEmpty ? position.timeAgoText : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(status: isMoving ? 'moving' : 'idle'),
        ],
      ),
    );
  }
}

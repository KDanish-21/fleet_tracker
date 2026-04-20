// lib/presentation/vehicles/vehicles_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleet_tracker/core/theme/app_theme.dart';
import 'package:fleet_tracker/core/utils/date_utils.dart';
import 'package:fleet_tracker/data/models/models.dart';
import 'package:fleet_tracker/data/repositories/vehicle_repository.dart';
import 'package:fleet_tracker/presentation/widgets/app_widgets.dart';

final _vehiclesListProvider = FutureProvider<List<VehicleModel>>((ref) async {
  final repo = ref.read(vehicleRepositoryProvider);
  final vehiclesResult = await repo.getVehicles();
  final positionsResult = await repo.getLivePositions();

  final vehicles = vehiclesResult.fold((_) => <VehicleModel>[], (v) => v);
  final positions = positionsResult.fold((_) => <PositionModel>[], (p) => p);

  // Merge position data into vehicles
  final posMap = <String, PositionModel>{};
  for (final p in positions) {
    if (p.deviceId != null) posMap[p.deviceId!] = p;
  }

  return vehicles.map((v) {
    final pos = posMap[v.deviceId];
    if (pos != null) return v.mergeWithPosition(pos);
    return v;
  }).toList();
});

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  String _search = '';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_vehiclesListProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        title: const Text('Vehicles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_vehiclesListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search vehicles...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['all', 'moving', 'idle', 'offline']
                    .map((f) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(f[0].toUpperCase() + f.substring(1)),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                            selectedColor: AppColors.primaryLight,
                            checkmarkColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: _filter == f
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: _filter == f
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),

          Expanded(
            child: async.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, __) => const ShimmerCard(height: 88),
              ),
              error: (e, _) => ErrorView(
                message: 'Could not load vehicles',
                onRetry: () => ref.invalidate(_vehiclesListProvider),
              ),
              data: (vehicles) {
                final filtered = vehicles.where((v) {
                  final matchSearch = _search.isEmpty ||
                      v.name.toLowerCase().contains(_search) ||
                      (v.plateNumber?.toLowerCase().contains(_search) ?? false);
                  final matchFilter = _filter == 'all' ||
                      v.displayStatus == _filter;
                  return matchSearch && matchFilter;
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyView(
                    message: 'No vehicles match your filter',
                    icon: Icons.local_shipping_rounded,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _VehicleTile(vehicle: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  final VehicleModel vehicle;
  const _VehicleTile({required this.vehicle});

  Color get _statusBg {
    switch (vehicle.displayStatus) {
      case 'moving': return AppColors.movingBg;
      case 'idle': return AppColors.idleBg;
      case 'offline': return AppColors.stoppedBg;
      default: return AppColors.offlineBg;
    }
  }

  Color get _statusColor {
    switch (vehicle.displayStatus) {
      case 'moving': return AppColors.moving;
      case 'idle': return AppColors.idle;
      case 'offline': return AppColors.danger;
      default: return AppColors.offline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_shipping_rounded,
                    color: _statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.name, style: AppTextStyles.h4),
                    const SizedBox(height: 2),
                    Text(
                      vehicle.deviceId ?? 'No device',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusBadge(status: vehicle.displayStatus),
            ],
          ),
          if (vehicle.speed != null || vehicle.lastUpdate != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                if (vehicle.speed != null) ...[
                  const Icon(Icons.speed_rounded,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${vehicle.speed!.toStringAsFixed(0)} km/h',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(width: 16),
                ],
                if (vehicle.driver != null) ...[
                  const Icon(Icons.person_rounded,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(vehicle.driver!, style: AppTextStyles.bodySmall),
                  const SizedBox(width: 16),
                ],
                const Spacer(),
                Text(
                  vehicle.timeAgoText.isNotEmpty
                      ? vehicle.timeAgoText
                      : (vehicle.lastUpdate != null
                          ? AppDateUtils.timeAgo(vehicle.lastUpdate)
                          : ''),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

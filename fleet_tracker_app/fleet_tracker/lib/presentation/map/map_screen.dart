// lib/presentation/map/map_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:fleet_tracker/core/constants/app_constants.dart';
import 'package:fleet_tracker/core/theme/app_theme.dart';
import 'package:fleet_tracker/core/utils/date_utils.dart';
import 'package:fleet_tracker/data/models/models.dart';
import 'package:fleet_tracker/data/repositories/vehicle_repository.dart';
import 'package:fleet_tracker/presentation/widgets/app_widgets.dart';

final _livePositionsProvider = FutureProvider<List<PositionModel>>((ref) async {
  final result = await ref.read(vehicleRepositoryProvider).getLivePositions();
  return result.fold((_) => [], (p) => p);
});

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  Timer? _timer;
  final _mapController = MapController();
  PositionModel? _selected;
  bool _showPanel = false;

  // Default center: Shenzhen area (where fleet devices are located)
  static const _defaultCenter = LatLng(22.59, 114.07);

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(
      const Duration(seconds: AppConstants.pollIntervalSeconds),
      (_) => ref.invalidate(_livePositionsProvider),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_livePositionsProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Stack(
        children: [
          // ─── Map ─────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 12,
              minZoom: 4,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.adrs.fleettracker',
              ),
              async.when(
                loading: () => const MarkerLayer(markers: []),
                error: (_, __) => const MarkerLayer(markers: []),
                data: (positions) => MarkerLayer(
                  markers: positions
                      .where((p) => p.hasValidLocation)
                      .map((p) => _buildMarker(p))
                      .toList(),
                ),
              ),
            ],
          ),

          // ─── Top Bar ─────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.map_rounded,
                              size: 18, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Text('Live Fleet Map',
                              style: AppTextStyles.h4.copyWith(fontSize: 15)),
                          const Spacer(),
                          async.when(
                            loading: () => const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5, color: AppColors.accent),
                            ),
                            error: (_, __) => const Icon(Icons.wifi_off_rounded,
                                size: 16, color: AppColors.danger),
                            data: (positions) => Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: AppColors.moving,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text('${positions.length} active',
                                    style: AppTextStyles.label.copyWith(
                                        color: AppColors.moving)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Fit all button
                  GestureDetector(
                    onTap: () => _fitAll(
                        ref.read(_livePositionsProvider).valueOrNull ?? []),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: const Icon(Icons.fit_screen_rounded,
                          size: 20, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Vehicle Detail Panel ─────────────────────────────────────────
          if (_showPanel && _selected != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _VehiclePanel(
                position: _selected!,
                onClose: () => setState(() {
                  _showPanel = false;
                  _selected = null;
                }),
              ),
            ),
        ],
      ),
    );
  }

  Marker _buildMarker(PositionModel p) {
    final isMoving = (p.speed ?? 0) > 2;
    final color = isMoving ? AppColors.moving : AppColors.idle;

    return Marker(
      point: LatLng(p.latitude!, p.longitude!),
      width: 48,
      height: 48,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selected = p;
            _showPanel = true;
          });
          _mapController.move(LatLng(p.latitude!, p.longitude!), 14);
        },
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(
            isMoving
                ? Icons.directions_car_rounded
                : Icons.local_shipping_rounded,
            color: color,
            size: 20,
          ),
        ),
      ),
    );
  }

  void _fitAll(List<PositionModel> positions) {
    final valid = positions.where((p) => p.hasValidLocation).toList();
    if (valid.isEmpty) return;
    if (valid.length == 1) {
      _mapController.move(
          LatLng(valid.first.latitude!, valid.first.longitude!), 13);
      return;
    }
    final bounds = LatLngBounds.fromPoints(
        valid.map((p) => LatLng(p.latitude!, p.longitude!)).toList());
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
  }
}

class _VehiclePanel extends StatelessWidget {
  final PositionModel position;
  final VoidCallback onClose;

  const _VehiclePanel({required this.position, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final isMoving = (position.speed ?? 0) > 2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_shipping_rounded,
                    color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        position.vehicleName ??
                            'Device ${position.deviceId}',
                        style: AppTextStyles.h4),
                    StatusBadge(status: isMoving ? 'moving' : 'idle'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppColors.textMuted,
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              _InfoChip(
                icon: Icons.speed_rounded,
                value: '${position.speed?.toStringAsFixed(0) ?? 0} km/h',
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.access_time_rounded,
                value: position.timeAgoText.isNotEmpty
                    ? position.timeAgoText
                    : AppDateUtils.timeAgo(position.timestamp),
              ),
              if (position.heading != null) ...[
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.navigation_rounded,
                  value: '${position.heading!.toStringAsFixed(0)}°',
                ),
              ],
            ],
          ),
          if (position.address != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(position.address!,
                      style: AppTextStyles.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String value;

  const _InfoChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Text(value,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

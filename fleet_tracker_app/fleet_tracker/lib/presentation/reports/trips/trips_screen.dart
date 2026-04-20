// lib/presentation/reports/trips/trips_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleet_tracker/core/theme/app_theme.dart';
import 'package:fleet_tracker/core/utils/date_utils.dart';
import 'package:fleet_tracker/data/models/models.dart';
import 'package:fleet_tracker/data/repositories/reports_repository.dart';
import 'package:fleet_tracker/data/repositories/vehicle_repository.dart';
import 'package:fleet_tracker/presentation/widgets/app_widgets.dart';

class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  DateTime _start = DateTime.now().subtract(const Duration(days: 7));
  DateTime _end = DateTime.now();
  String? _selectedDeviceId;
  TripsResponse? _result;
  bool _loading = false;
  String? _error;
  List<VehicleModel> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    final result = await ref.read(vehicleRepositoryProvider).getVehicles();
    if (!mounted) return;
    result.fold((_) {}, (v) {
      final withDevice = v.where((x) => x.deviceId != null).toList();
      setState(() {
        _vehicles = v;
        if (withDevice.isNotEmpty) {
          _selectedDeviceId = withDevice.first.deviceId;
        }
      });
    });
  }

  Future<void> _fetchReport() async {
    if (_selectedDeviceId == null) {
      setState(() => _error = 'Please select a vehicle');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    final result = await ref.read(reportsRepositoryProvider).getTrips(
          deviceId: _selectedDeviceId!,
          startDate: _start,
          endDate: _end,
        );

    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _error = f.message;
        _loading = false;
      }),
      (r) => setState(() {
        _result = r;
        _loading = false;
      }),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(title: const Text('Trip Report')),
      body: Column(
        children: [
          // ─── Filters ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Column(
              children: [
                // Vehicle picker
                if (_vehicles.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedDeviceId,
                    dropdownColor: AppColors.card,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Vehicle',
                      prefixIcon: Icon(Icons.local_shipping_rounded),
                    ),
                    items: _vehicles
                        .where((v) => v.deviceId != null)
                        .map((v) => DropdownMenuItem(
                              value: v.deviceId,
                              child: Text(v.name),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() {
                      _selectedDeviceId = val;
                    }),
                  ),
                const SizedBox(height: 12),

                // Date range
                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: 'From',
                        date: _start,
                        onTap: () => _pickDate(true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateButton(
                        label: 'To',
                        date: _end,
                        onTap: () => _pickDate(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _fetchReport,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Generate Report'),
                  ),
                ),
              ],
            ),
          ),

          // ─── Results ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const AppLoadingIndicator()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _fetchReport)
                    : _result == null
                        ? const EmptyView(
                            message:
                                'Select a vehicle and date range, then tap Generate',
                            icon: Icons.route_rounded,
                          )
                        : _buildResults(_result!),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(TripsResponse result) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary cards
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Total Trips',
                value: '${result.totalTrips}',
                icon: Icons.route_rounded,
                iconColor: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Total Distance',
                value:
                    '${result.totalDistance.toStringAsFixed(1)} km',
                icon: Icons.straighten_rounded,
                iconColor: AppColors.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        const SectionHeader(title: 'Trip Details'),

        if (result.trips.isEmpty)
          const EmptyView(
              message: 'No trips found for this period',
              icon: Icons.route_rounded)
        else
          ...result.trips.map((trip) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TripCard(trip: trip),
              )),
      ],
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripRecord trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.route_rounded,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${AppDateUtils.toTimeOnly(trip.startTime)} → ${AppDateUtils.toTimeOnly(trip.endTime)}',
                  style: AppTextStyles.h4.copyWith(fontSize: 14),
                ),
              ),
              if (trip.distance != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${trip.distance!.toStringAsFixed(1)} km',
                    style: AppTextStyles.label.copyWith(
                        color: AppColors.accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (trip.maxSpeed != null)
                _Chip(
                  icon: Icons.speed_rounded,
                  label: 'Max ${trip.maxSpeed!.toStringAsFixed(0)} km/h',
                ),
              if (trip.avgSpeed != null) ...[
                const SizedBox(width: 6),
                _Chip(
                  icon: Icons.speed_outlined,
                  label: 'Avg ${trip.avgSpeed!.toStringAsFixed(0)} km/h',
                ),
              ],
              if (trip.duration != null) ...[
                const SizedBox(width: 6),
                _Chip(
                  icon: Icons.timer_outlined,
                  label: _formatDuration(trip.duration!),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.label),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateButton(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.label.copyWith(fontSize: 10)),
                Text(AppDateUtils.toDisplayDate(date),
                    style: AppTextStyles.body
                        .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

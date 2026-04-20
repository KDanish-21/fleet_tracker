// lib/presentation/reports/fuel/fuel_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fleet_tracker/core/theme/app_theme.dart';
import 'package:fleet_tracker/core/utils/date_utils.dart';
import 'package:fleet_tracker/data/models/models.dart';
import 'package:fleet_tracker/data/repositories/reports_repository.dart';
import 'package:fleet_tracker/data/repositories/vehicle_repository.dart';
import 'package:fleet_tracker/presentation/widgets/app_widgets.dart';

class FuelScreen extends ConsumerStatefulWidget {
  const FuelScreen({super.key});

  @override
  ConsumerState<FuelScreen> createState() => _FuelScreenState();
}

class _FuelScreenState extends ConsumerState<FuelScreen> {
  DateTime _start = DateTime.now().subtract(const Duration(days: 30));
  DateTime _end = DateTime.now();
  List<VehicleModel> _vehicles = [];
  final Set<String> _selectedIds = {};
  List<FuelRecord>? _records;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    final result = await ref.read(vehicleRepositoryProvider).getVehicles();
    if (!mounted) return;
    result.fold((_) {}, (v) {
      setState(() {
        _vehicles = v;
        _selectedIds.addAll(v
            .where((x) => x.deviceId != null)
            .map((x) => x.deviceId!)
            .take(5));
      });
    });
  }

  Future<void> _fetch() async {
    if (_selectedIds.isEmpty) {
      setState(() => _error = 'Select at least one vehicle');
      return;
    }
    setState(() { _loading = true; _error = null; _records = null; });

    final result = await ref.read(reportsRepositoryProvider).getFuel(
          deviceIds: _selectedIds.toList(),
          startDate: _start,
          endDate: _end,
        );

    if (!mounted) return;
    result.fold(
      (f) => setState(() { _error = f.message; _loading = false; }),
      (r) => setState(() { _records = r; _loading = false; }),
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
            colorScheme: const ColorScheme.dark(primary: AppColors.accent)),
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
      appBar: AppBar(title: const Text('Fuel Report')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Vehicles', style: AppTextStyles.h4.copyWith(fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _vehicles.where((v) => v.deviceId != null).map((v) {
                    final sel = _selectedIds.contains(v.deviceId);
                    return FilterChip(
                      label: Text(v.name),
                      selected: sel,
                      onSelected: (s) => setState(() {
                        if (s) {
                          _selectedIds.add(v.deviceId!);
                        } else {
                          _selectedIds.remove(v.deviceId);
                        }
                      }),
                      selectedColor: AppColors.danger.withOpacity(0.2),
                      checkmarkColor: AppColors.danger,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickDate(true),
                        child: _buildDateTile('From', _start),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickDate(false),
                        child: _buildDateTile('To', _end),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _fetch,
                    icon: const Icon(Icons.local_gas_station_rounded, size: 18),
                    label: const Text('Fetch Fuel Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const AppLoadingIndicator()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _fetch)
                    : _records == null
                        ? const EmptyView(
                            message: 'Select vehicles and date range to view fuel data',
                            icon: Icons.local_gas_station_rounded)
                        : _buildResults(_records!),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(List<FuelRecord> records) {
    if (records.isEmpty) {
      return const EmptyView(
          message: 'No fuel data found for this period',
          icon: Icons.local_gas_station_rounded);
    }

    final totalFuel = records.fold<double>(
        0, (sum, r) => sum + (r.fuelUsed ?? 0));
    final totalDist = records.fold<double>(
        0, (sum, r) => sum + (r.distance ?? 0));
    final avgConsumption = totalDist > 0 ? (totalFuel / totalDist) * 100 : 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Total Fuel Used',
                value: '${totalFuel.toStringAsFixed(1)} L',
                icon: Icons.local_gas_station_rounded,
                iconColor: AppColors.danger,
                valueColor: AppColors.danger,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Avg Consumption',
                value: '${avgConsumption.toStringAsFixed(1)} L/100km',
                icon: Icons.speed_rounded,
                iconColor: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Chart
        if (records.length > 1) ...[
          const SectionHeader(title: 'Fuel Usage Chart'),
          Container(
            height: 180,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: records.map((r) => r.fuelUsed ?? 0).reduce(
                        (a, b) => a > b ? a : b) *
                    1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= records.length) {
                          return const SizedBox();
                        }
                        return Text(
                          records[idx].vehicleName?.split(' ').first ?? '$idx',
                          style: AppTextStyles.label.copyWith(fontSize: 9),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: records.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.fuelUsed ?? 0,
                        color: AppColors.danger,
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        const SectionHeader(title: 'Details'),
        ...records.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FuelTile(record: r),
            )),
      ],
    );
  }

  Widget _buildDateTile(String label, DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.label.copyWith(fontSize: 9)),
              Text(AppDateUtils.toDisplayDate(date),
                  style: AppTextStyles.body
                      .copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FuelTile extends StatelessWidget {
  final FuelRecord record;
  const _FuelTile({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.local_gas_station_rounded,
                  size: 16, color: AppColors.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(record.vehicleName ?? 'Unknown Vehicle',
                    style: AppTextStyles.h4.copyWith(fontSize: 14)),
              ),
              if (record.fuelUsed != null)
                Text('${record.fuelUsed!.toStringAsFixed(1)} L',
                    style: AppTextStyles.h4
                        .copyWith(color: AppColors.danger, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (record.distance != null)
                _InfoBadge(
                  icon: Icons.straighten_rounded,
                  value: '${record.distance!.toStringAsFixed(1)} km',
                ),
              if (record.fuelIn != null) ...[
                const SizedBox(width: 6),
                _InfoBadge(
                  icon: Icons.arrow_downward_rounded,
                  value: '+ ${record.fuelIn!.toStringAsFixed(1)} L',
                  color: AppColors.success,
                ),
              ],
              if (record.timestamp != null) ...[
                const Spacer(),
                Text(AppDateUtils.toDisplayDate(DateTime.tryParse(record.timestamp!) ?? DateTime.now()),
                    style: AppTextStyles.label.copyWith(fontSize: 10)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? color;

  const _InfoBadge({required this.icon, required this.value, this.color});

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
          Icon(icon,
              size: 12, color: color ?? AppColors.textMuted),
          const SizedBox(width: 4),
          Text(value,
              style: AppTextStyles.label.copyWith(
                  color: color ?? AppColors.textSecondary)),
        ],
      ),
    );
  }
}

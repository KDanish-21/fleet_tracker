// lib/presentation/reports/alarms/alarms_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleet_tracker/core/theme/app_theme.dart';
import 'package:fleet_tracker/core/utils/date_utils.dart';
import 'package:fleet_tracker/data/models/models.dart';
import 'package:fleet_tracker/data/repositories/reports_repository.dart';
import 'package:fleet_tracker/data/repositories/vehicle_repository.dart';
import 'package:fleet_tracker/presentation/widgets/app_widgets.dart';

class AlarmsScreen extends ConsumerStatefulWidget {
  const AlarmsScreen({super.key});

  @override
  ConsumerState<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends ConsumerState<AlarmsScreen> {
  DateTime _start = DateTime.now().subtract(const Duration(days: 7));
  DateTime _end = DateTime.now();
  List<VehicleModel> _vehicles = [];
  final Set<String> _selectedIds = {};
  List<AlarmRecord>? _records;
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
            .take(3));
      });
    });
  }

  Future<void> _fetch() async {
    if (_selectedIds.isEmpty) {
      setState(() => _error = 'Select at least one vehicle');
      return;
    }
    setState(() { _loading = true; _error = null; _records = null; });

    final result = await ref.read(reportsRepositoryProvider).getAlarms(
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
      appBar: AppBar(title: const Text('Alarm Report')),
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
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _vehicles.where((v) => v.deviceId != null).map((v) {
                    final selected = _selectedIds.contains(v.deviceId);
                    return FilterChip(
                      label: Text(v.name),
                      selected: selected,
                      onSelected: (s) => setState(() {
                        if (s) {
                          _selectedIds.add(v.deviceId!);
                        } else {
                          _selectedIds.remove(v.deviceId);
                        }
                      }),
                      selectedColor: AppColors.warning.withOpacity(0.2),
                      checkmarkColor: AppColors.warning,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickDate(true),
                        child: _DateChip(label: 'From', date: _start),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickDate(false),
                        child: _DateChip(label: 'To', date: _end),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _fetch,
                    icon: const Icon(Icons.warning_amber_rounded, size: 18),
                    label: const Text('Fetch Alarms'),
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
                            message: 'Configure filters and fetch alarms',
                            icon: Icons.warning_amber_rounded)
                        : _records!.isEmpty
                            ? const EmptyView(
                                message: 'No alarms in this period ✓',
                                icon: Icons.check_circle_outline_rounded)
                            : _buildList(_records!),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<AlarmRecord> records) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Text('${records.length} Alarms',
                    style: AppTextStyles.label.copyWith(color: AppColors.warning)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _AlarmTile(alarm: records[i]),
          ),
        ),
      ],
    );
  }
}

class _AlarmTile extends StatelessWidget {
  final AlarmRecord alarm;
  const _AlarmTile({required this.alarm});

  Color get _color {
    final t = alarm.alarmType?.toLowerCase() ?? '';
    if (t.contains('speed')) return AppColors.danger;
    if (t.contains('geo')) return AppColors.info;
    if (t.contains('power') || t.contains('voltage')) return AppColors.warning;
    return AppColors.warning;
  }

  IconData get _icon {
    final t = alarm.alarmType?.toLowerCase() ?? '';
    if (t.contains('speed')) return Icons.speed_rounded;
    if (t.contains('geo')) return Icons.fence_rounded;
    if (t.contains('power')) return Icons.bolt_rounded;
    return Icons.warning_amber_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: _color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alarm.alarmType ?? 'Unknown Alarm',
                    style: AppTextStyles.h4.copyWith(
                        fontSize: 13, color: _color)),
                const SizedBox(height: 2),
                Text(alarm.vehicleName ?? 'Unknown Vehicle',
                    style: AppTextStyles.body.copyWith(fontSize: 13)),
                if (alarm.address != null) ...[
                  const SizedBox(height: 2),
                  Text(alarm.address!,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(AppDateUtils.toDisplayDateTime(alarm.timestamp),
                  style: AppTextStyles.label.copyWith(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final DateTime date;
  const _DateChip({required this.label, required this.date});

  @override
  Widget build(BuildContext context) {
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

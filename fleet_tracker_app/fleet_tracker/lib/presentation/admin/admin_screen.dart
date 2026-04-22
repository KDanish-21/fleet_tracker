import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleet_tracker/core/theme/app_theme.dart';
import 'package:fleet_tracker/data/models/models.dart';
import 'package:fleet_tracker/data/repositories/admin_repository.dart';
import 'package:fleet_tracker/data/repositories/auth_repository.dart';
import 'package:fleet_tracker/presentation/widgets/app_widgets.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  UserModel? _user;
  String _tenantSlug = '';
  AdminStats? _stats;
  List<TenantModel> _tenants = [];
  TenantModel? _selectedTenant;
  List<UserModel> _users = [];
  List<TenantDeviceModel> _devices = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;

  bool get _isSuperadmin => _user?.role == 'superadmin';
  bool get _canManage =>
      _isSuperadmin || _user?.role == 'owner' || _user?.role == 'admin';
  String? get _scopeTenantId => _isSuperadmin ? _selectedTenant?.id : null;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = ref.read(authRepositoryProvider);
    final admin = ref.read(adminRepositoryProvider);
    final user = await auth.getCachedUser();
    final tenantSlug = await auth.getTenantSlug();

    if (!mounted) return;
    _user = user;
    _tenantSlug = tenantSlug;

    if (!_canManage) {
      setState(() => _loading = false);
      return;
    }

    if (_isSuperadmin) {
      final statsResult = await admin.getSuperadminStats();
      final tenantsResult = await admin.getTenants();
      final stats = statsResult.fold((f) {
        _error = f.message;
        return null;
      }, (s) => s);
      final tenants = tenantsResult.fold((f) {
        _error = f.message;
        return <TenantModel>[];
      }, (t) => t);

      _stats = stats;
      _tenants = tenants;
      final previousTenantId = _selectedTenant?.id;
      if (previousTenantId == null) {
        _selectedTenant = tenants.isEmpty ? null : tenants.first;
      } else {
        final matches = tenants.where((t) => t.id == previousTenantId);
        _selectedTenant = matches.isEmpty
            ? (tenants.isEmpty ? null : tenants.first)
            : matches.first;
      }
    }

    await _loadScopedLists();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadScopedLists() async {
    if (_isSuperadmin && _selectedTenant == null) {
      _users = [];
      _devices = [];
      return;
    }

    final admin = ref.read(adminRepositoryProvider);
    final usersResult = await admin.getUsers(
      tenantId: _scopeTenantId,
      superadmin: _isSuperadmin,
    );
    final devicesResult = await admin.getDevices(
      tenantId: _scopeTenantId,
      superadmin: _isSuperadmin,
    );

    _users = usersResult.fold((f) {
      _error = f.message;
      return <UserModel>[];
    }, (u) => u);
    _devices = devicesResult.fold((f) {
      _error = f.message;
      return <TenantDeviceModel>[];
    }, (d) => d);
  }

  Future<void> _refreshScoped() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _loadScopedLists();
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveTenant({TenantModel? tenant}) async {
    final slugCtrl = TextEditingController(text: tenant?.slug ?? '');
    final nameCtrl = TextEditingController(text: tenant?.name ?? '');
    final currencyCtrl = TextEditingController(text: tenant?.currency ?? 'USD');
    var active = tenant?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tenant == null ? 'Add Tenant' : 'Edit Tenant'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: slugCtrl,
                  enabled: tenant == null,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
                    TextInputFormatter.withFunction(
                      (oldValue, newValue) => newValue.copyWith(
                        text: newValue.text.toLowerCase(),
                        selection: newValue.selection,
                      ),
                    ),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Tenant ID',
                    prefixIcon: Icon(Icons.badge_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Company Name',
                    prefixIcon: Icon(Icons.business_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: currencyCtrl,
                  maxLength: 3,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    prefixIcon: Icon(Icons.payments_rounded),
                    counterText: '',
                  ),
                ),
                if (tenant != null) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: active,
                    onChanged: (v) => setDialogState(() => active = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final admin = ref.read(adminRepositoryProvider);
    final result = tenant == null
        ? await admin.createTenant(
            slug: slugCtrl.text.trim(),
            name: nameCtrl.text.trim(),
            currency: currencyCtrl.text.trim().toUpperCase(),
          )
        : await admin.updateTenant(
            tenantId: tenant.id,
            name: nameCtrl.text.trim(),
            currency: currencyCtrl.text.trim().toUpperCase(),
            isActive: active,
          );

    result.fold((f) => _snack(f.message), (_) {
      _snack('Tenant saved');
      _load();
    });
  }

  Future<void> _saveUser({UserModel? user}) async {
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final emailCtrl = TextEditingController(text: user?.email ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    final passCtrl = TextEditingController();
    var role = user?.role == 'owner'
        ? 'owner'
        : user?.role == 'admin'
            ? 'admin'
            : 'user';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(user == null ? 'Add User' : 'Edit User Role'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  enabled: user == null,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  enabled: user == null,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  enabled: user == null,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                ),
                if (user == null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_rounded),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.verified_user_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('User')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'owner', child: Text('Owner')),
                  ],
                  onChanged: (v) => setDialogState(() => role = v ?? 'user'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final admin = ref.read(adminRepositoryProvider);
    final result = user == null
        ? await admin.createUser(
            tenantId: _scopeTenantId,
            superadmin: _isSuperadmin,
            name: nameCtrl.text.trim(),
            email: emailCtrl.text.trim(),
            phone: phoneCtrl.text.trim(),
            password: passCtrl.text,
            role: role,
          )
        : await admin.updateUserRole(
            tenantId: _scopeTenantId,
            superadmin: _isSuperadmin,
            userId: user.id,
            role: role,
          );

    result.fold((f) => _snack(f.message), (_) {
      _snack('User saved');
      _refreshScoped();
    });
  }

  Future<void> _saveDevice({TenantDeviceModel? device}) async {
    final idCtrl = TextEditingController(text: device?.deviceId ?? '');
    final nameCtrl = TextEditingController(text: device?.deviceName ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(device == null ? 'Assign Truck' : 'Edit Truck'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idCtrl,
                enabled: device == null,
                decoration: const InputDecoration(
                  labelText: 'Device ID',
                  prefixIcon: Icon(Icons.memory_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Truck Name',
                  prefixIcon: Icon(Icons.local_shipping_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    final result = await ref.read(adminRepositoryProvider).upsertDevice(
          tenantId: _scopeTenantId,
          superadmin: _isSuperadmin,
          deviceId: idCtrl.text.trim(),
          deviceName: nameCtrl.text.trim(),
        );
    result.fold((f) => _snack(f.message), (_) {
      _snack('Truck assignment saved');
      _refreshScoped();
    });
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirmed = await _confirm('Delete ${user.name}?');
    if (!confirmed) return;
    final result = await ref.read(adminRepositoryProvider).deleteUser(
          tenantId: _scopeTenantId,
          superadmin: _isSuperadmin,
          userId: user.id,
        );
    result.fold((f) => _snack(f.message), (_) {
      _snack('User deleted');
      _refreshScoped();
    });
  }

  Future<void> _deleteDevice(TenantDeviceModel device) async {
    final confirmed =
        await _confirm('Remove ${device.deviceId} from this tenant?');
    if (!confirmed) return;
    final result = await ref.read(adminRepositoryProvider).deleteDevice(
          tenantId: _scopeTenantId,
          superadmin: _isSuperadmin,
          deviceId: device.deviceId,
        );
    result.fold((f) => _snack(f.message), (_) {
      _snack('Truck removed');
      _refreshScoped();
    });
  }

  Future<bool> _confirm(String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        floatingActionButton: _canManage ? _buildFab() : null,
        body: _loading
            ? const AppLoadingIndicator()
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _Header(
                      role: _user?.role ?? 'user',
                      tenant: _isSuperadmin
                          ? (_selectedTenant?.slug ?? 'no tenant selected')
                          : (_tenantSlug.isEmpty ? '-' : _tenantSlug),
                      isSuperadmin: _isSuperadmin,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: _Notice(message: _error!),
                      ),
                    if (!_canManage)
                      const SizedBox(
                        height: 420,
                        child: EmptyView(
                          message:
                              'Your account does not have admin permissions.',
                          icon: Icons.lock_outline_rounded,
                        ),
                      )
                    else ...[
                      if (_isSuperadmin) _buildSuperadminSummary(),
                      _buildTabs(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 88),
                        child: _tab == 0
                            ? _buildUsers()
                            : _tab == 1
                                ? _buildDevices()
                                : _buildTenants(),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget? _buildFab() {
    if (_isSuperadmin && _tab == 2) {
      return FloatingActionButton(
        onPressed: () => _saveTenant(),
        child: const Icon(Icons.business_rounded),
      );
    }
    if (_isSuperadmin && _selectedTenant == null) return null;
    return FloatingActionButton(
      onPressed: () => _tab == 0 ? _saveUser() : _saveDevice(),
      child:
          Icon(_tab == 0 ? Icons.person_add_rounded : Icons.add_road_rounded),
    );
  }

  Widget _buildSuperadminSummary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Tenants',
                  value: '${_stats?.tenants ?? _tenants.length}',
                  icon: Icons.business_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: 'Users',
                  value: '${_stats?.users ?? 0}',
                  icon: Icons.group_rounded,
                  iconColor: AppColors.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: 'Trucks',
                  value: '${_stats?.devices ?? 0}',
                  icon: Icons.local_shipping_rounded,
                  iconColor: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedTenant?.id,
            decoration: const InputDecoration(
              labelText: 'Manage Tenant',
              prefixIcon: Icon(Icons.apartment_rounded),
            ),
            items: _tenants
                .map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.name} (${t.slug})'),
                    ))
                .toList(),
            onChanged: (id) async {
              setState(() {
                _selectedTenant = _tenants.firstWhere((t) => t.id == id);
                _loading = true;
              });
              await _loadScopedLists();
              if (mounted) setState(() => _loading = false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = [
      const _AdminTab(Icons.group_rounded, 'Users'),
      const _AdminTab(Icons.local_shipping_rounded, 'Trucks'),
      if (_isSuperadmin) const _AdminTab(Icons.business_rounded, 'Tenants'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _tab == i;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == tabs.length - 1 ? 0 : 8),
              child: InkWell(
                onTap: () => setState(() => _tab = i),
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primaryLight : AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          selected ? AppColors.primary : AppColors.cardBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(tabs[i].icon,
                          size: 18,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        tabs[i].label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildUsers() {
    if (_users.isEmpty) {
      return const SizedBox(
        height: 360,
        child: EmptyView(
            message: 'No users in this tenant', icon: Icons.group_rounded),
      );
    }
    return Column(
      children: _users
          .map((user) => _AdminListTile(
                icon: Icons.person_rounded,
                title: user.name,
                subtitle: '${user.email}  |  ${user.role}',
                trailing: [
                  IconButton(
                    tooltip: 'Edit role',
                    onPressed: () => _saveUser(user: user),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                  IconButton(
                    tooltip: 'Delete user',
                    onPressed: () => _deleteUser(user),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ))
          .toList(),
    );
  }

  Widget _buildDevices() {
    if (_devices.isEmpty) {
      return const SizedBox(
        height: 360,
        child: EmptyView(
          message: 'No trucks assigned to this tenant',
          icon: Icons.local_shipping_rounded,
        ),
      );
    }
    return Column(
      children: _devices
          .map((device) => _AdminListTile(
                icon: Icons.local_shipping_rounded,
                title: device.deviceName.isEmpty
                    ? device.deviceId
                    : device.deviceName,
                subtitle: device.deviceId,
                trailing: [
                  IconButton(
                    tooltip: 'Edit truck',
                    onPressed: () => _saveDevice(device: device),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                  IconButton(
                    tooltip: 'Remove truck',
                    onPressed: () => _deleteDevice(device),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ))
          .toList(),
    );
  }

  Widget _buildTenants() {
    if (_tenants.isEmpty) {
      return const SizedBox(
        height: 360,
        child:
            EmptyView(message: 'No tenants yet', icon: Icons.business_rounded),
      );
    }
    return Column(
      children: _tenants
          .map((tenant) => _AdminListTile(
                icon: Icons.business_rounded,
                title: tenant.name,
                subtitle:
                    '${tenant.slug}  |  ${tenant.deviceCount} trucks  |  ${tenant.userCount} users',
                badge: tenant.isActive ? 'active' : 'inactive',
                trailing: [
                  IconButton(
                    tooltip: 'Manage tenant',
                    onPressed: () async {
                      setState(() {
                        _selectedTenant = tenant;
                        _tab = 0;
                        _loading = true;
                      });
                      await _loadScopedLists();
                      if (mounted) setState(() => _loading = false);
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                  ),
                  IconButton(
                    tooltip: 'Edit tenant',
                    onPressed: () => _saveTenant(tenant: tenant),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                ],
              ))
          .toList(),
    );
  }
}

class _Header extends StatelessWidget {
  final String role;
  final String tenant;
  final bool isSuperadmin;

  const _Header({
    required this.role,
    required this.tenant,
    required this.isSuperadmin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 70, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroFrom, AppColors.heroVia, Color(0xFF312E81)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Icon(
              isSuperadmin
                  ? Icons.admin_panel_settings_rounded
                  : Icons.verified_user_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Console',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$role | $tenant',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTab {
  final IconData icon;
  final String label;

  const _AdminTab(this.icon, this.label);
}

class _Notice extends StatelessWidget {
  final String message;

  const _Notice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final List<Widget> trailing;

  const _AdminListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h4,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        badge!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: badge == 'active'
                              ? AppColors.success
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

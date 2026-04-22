// lib/data/models/user_model.dart
import 'dart:convert';

class UserModel {
  final String id;
  final String? tenantId;
  final String? tenantSlug;
  final String? tenantName;
  final String role;
  final String name;
  final String email;
  final String phone;
  final String? createdAt;

  const UserModel({
    required this.id,
    this.tenantId,
    this.tenantSlug,
    this.tenantName,
    this.role = 'user',
    required this.name,
    required this.email,
    required this.phone,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] ?? '',
        tenantId: json['tenant_id'],
        tenantSlug: json['tenant_slug'],
        tenantName: json['tenant_name'],
        role: json['role'] ?? 'user',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'] ?? '',
        createdAt: json['created_at'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'tenant_slug': tenantSlug,
        'tenant_name': tenantName,
        'role': role,
        'name': name,
        'email': email,
        'phone': phone,
        'created_at': createdAt,
      };

  String toJsonString() => jsonEncode(toJson());
  factory UserModel.fromJsonString(String s) =>
      UserModel.fromJson(jsonDecode(s));
}

// lib/data/models/tenant_model.dart
class TenantModel {
  final String id;
  final String slug;
  final String name;
  final String currency;
  final bool isActive;
  final int userCount;
  final int deviceCount;
  final String? createdAt;

  const TenantModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.currency,
    required this.isActive,
    this.userCount = 0,
    this.deviceCount = 0,
    this.createdAt,
  });

  factory TenantModel.fromJson(Map<String, dynamic> json) => TenantModel(
        id: json['id'] ?? '',
        slug: json['slug'] ?? '',
        name: json['name'] ?? '',
        currency: json['currency'] ?? 'USD',
        isActive: json['is_active'] ?? true,
        userCount: _toInt(json['user_count']),
        deviceCount: _toInt(json['device_count']),
        createdAt: json['created_at'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'currency': currency,
        'is_active': isActive,
        'user_count': userCount,
        'device_count': deviceCount,
        'created_at': createdAt,
      };

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

// lib/data/models/admin_model.dart
class AdminStats {
  final int tenants;
  final int users;
  final int devices;

  const AdminStats({
    required this.tenants,
    required this.users,
    required this.devices,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
        tenants: _toInt(json['tenants']),
        users: _toInt(json['users']),
        devices: _toInt(json['devices']),
      );

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class TenantDeviceModel {
  final String deviceId;
  final String deviceName;
  final String? createdAt;

  const TenantDeviceModel({
    required this.deviceId,
    required this.deviceName,
    this.createdAt,
  });

  factory TenantDeviceModel.fromJson(Map<String, dynamic> json) =>
      TenantDeviceModel(
        deviceId: (json['device_id'] ?? json['deviceid'] ?? '').toString(),
        deviceName:
            (json['device_name'] ?? json['devicename'] ?? json['name'] ?? '')
                .toString(),
        createdAt: json['created_at']?.toString(),
      );
}

// lib/data/models/auth_model.dart
class AuthResponse {
  final String token;
  final UserModel user;
  final TenantModel? tenant;

  const AuthResponse({
    required this.token,
    required this.user,
    this.tenant,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        token: json['token'] ?? json['access_token'] ?? '',
        user: UserModel.fromJson(json['user'] ?? {}),
        tenant: json['tenant'] is Map<String, dynamic>
            ? TenantModel.fromJson(json['tenant'])
            : null,
      );
}

// lib/data/models/vehicle_model.dart
class VehicleModel {
  final String id;
  final String name;
  final String? plateNumber;
  final String? type;
  final String? status;
  final String? deviceId;
  final String? groupName;
  final double? latitude;
  final double? longitude;
  final double? speed;
  final double? totalDistanceKm;
  final double? fuelL;
  final int? deviceTime;
  final String? lastUpdate;
  final String? driver;
  final String? gpsSource;
  final int? gpsSats;
  final int? gsmSignal;
  final bool? moving;

  const VehicleModel({
    required this.id,
    required this.name,
    this.plateNumber,
    this.type,
    this.status,
    this.deviceId,
    this.groupName,
    this.latitude,
    this.longitude,
    this.speed,
    this.totalDistanceKm,
    this.fuelL,
    this.deviceTime,
    this.lastUpdate,
    this.driver,
    this.gpsSource,
    this.gpsSats,
    this.gsmSignal,
    this.moving,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) => VehicleModel(
        id: (json['deviceid'] ?? json['id'] ?? '').toString(),
        name: json['devicename'] ??
            json['name'] ??
            json['vehicle_name'] ??
            'Unknown',
        plateNumber: json['plate_number'] ?? json['plate'],
        type: json['device_model']?.toString() ?? json['type'],
        status: json['status']?.toString(),
        deviceId: (json['deviceid'] ?? json['device_id'] ?? '').toString(),
        groupName: json['groupname'],
        latitude: _toDouble(json['lat'] ?? json['latitude']),
        longitude: _toDouble(json['lng'] ?? json['longitude']),
        speed: _toDouble(json['speed']),
        totalDistanceKm: _toDouble(json['total_distance_km']),
        fuelL: _toDouble(json['fuel_l']),
        deviceTime: json['device_time'] is int ? json['device_time'] : null,
        lastUpdate: json['last_update'] ?? json['updated_at'],
        driver: json['driver'],
        gpsSource: json['gps_source'],
        gpsSats: json['gps_sats'] is int ? json['gps_sats'] : null,
        gsmSignal: json['gsm_signal'] is int ? json['gsm_signal'] : null,
        moving: json['moving'] is bool ? json['moving'] : null,
      );

  VehicleModel mergeWithPosition(PositionModel pos) => VehicleModel(
        id: id,
        name: name,
        plateNumber: plateNumber,
        type: type,
        status: status,
        deviceId: deviceId,
        groupName: groupName,
        latitude: pos.latitude,
        longitude: pos.longitude,
        speed: pos.speed,
        totalDistanceKm: pos.totalDistanceKm,
        fuelL: pos.fuelL,
        deviceTime: pos.deviceTime,
        lastUpdate: lastUpdate,
        driver: driver,
        gpsSource: pos.gpsSource,
        gpsSats: pos.gpsSats,
        gsmSignal: pos.gsmSignal,
        moving: pos.moving,
      );

  bool get isMoving => moving ?? (speed ?? 0) > 2;

  bool get isOnline {
    if (deviceTime != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(deviceTime! * 1000);
      return DateTime.now().difference(dt).inMinutes < 30;
    }
    if (lastUpdate == null) return false;
    try {
      final dt = DateTime.parse(lastUpdate!);
      return DateTime.now().difference(dt).inMinutes < 30;
    } catch (_) {
      return false;
    }
  }

  String get displayStatus {
    if (!isOnline) return 'offline';
    if (isMoving) return 'moving';
    return 'idle';
  }

  String get timeAgoText {
    if (deviceTime != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(deviceTime! * 1000);
      return _formatTimeAgo(dt);
    }
    return '';
  }

  static String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

// lib/data/models/position_model.dart
class PositionModel {
  final String? deviceId;
  final double? latitude;
  final double? longitude;
  final double? speed;
  final double? heading;
  final int? deviceTime;
  final String? timestamp;
  final String? address;
  final String? vehicleName;
  final double? totalDistanceKm;
  final double? fuelL;
  final String? gpsSource;
  final int? gpsSats;
  final int? gsmSignal;
  final bool? moving;

  const PositionModel({
    this.deviceId,
    this.latitude,
    this.longitude,
    this.speed,
    this.heading,
    this.deviceTime,
    this.timestamp,
    this.address,
    this.vehicleName,
    this.totalDistanceKm,
    this.fuelL,
    this.gpsSource,
    this.gpsSats,
    this.gsmSignal,
    this.moving,
  });

  factory PositionModel.fromJson(Map<String, dynamic> json) => PositionModel(
        deviceId: (json['deviceid'] ?? json['device_id'] ?? '').toString(),
        latitude: _toDouble(json['lat'] ?? json['latitude']),
        longitude: _toDouble(json['lng'] ?? json['longitude']),
        speed: _toDouble(json['speed']),
        heading: _toDouble(json['course'] ?? json['heading']),
        deviceTime: json['device_time'] is int ? json['device_time'] : null,
        timestamp: json['timestamp'] ?? json['time'],
        address: json['address'],
        vehicleName: json['devicename'] ?? json['vehicle_name'] ?? json['name'],
        totalDistanceKm: _toDouble(json['total_distance_km']),
        fuelL: _toDouble(json['fuel_l']),
        gpsSource: json['gps_source'],
        gpsSats: json['gps_sats'] is int ? json['gps_sats'] : null,
        gsmSignal: json['gsm_signal'] is int ? json['gsm_signal'] : null,
        moving: json['moving'] is bool ? json['moving'] : null,
      );

  PositionModel withVehicleName(String name) => PositionModel(
        deviceId: deviceId,
        latitude: latitude,
        longitude: longitude,
        speed: speed,
        heading: heading,
        deviceTime: deviceTime,
        timestamp: timestamp,
        address: address,
        vehicleName: name,
        totalDistanceKm: totalDistanceKm,
        fuelL: fuelL,
        gpsSource: gpsSource,
        gpsSats: gpsSats,
        gsmSignal: gsmSignal,
        moving: moving,
      );

  bool get isMoving => moving ?? (speed ?? 0) > 2;

  bool get hasValidLocation =>
      latitude != null && longitude != null && latitude != 0 && longitude != 0;

  String get timeAgoText {
    if (deviceTime != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(deviceTime! * 1000);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    }
    return '';
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

// lib/data/models/trip_model.dart
class TripRecord {
  final String? vehicleName;
  final String? deviceId;
  final String? startTime;
  final String? endTime;
  final double? distance;
  final double? maxSpeed;
  final double? avgSpeed;
  final int? duration;

  const TripRecord({
    this.vehicleName,
    this.deviceId,
    this.startTime,
    this.endTime,
    this.distance,
    this.maxSpeed,
    this.avgSpeed,
    this.duration,
  });

  factory TripRecord.fromJson(Map<String, dynamic> json) => TripRecord(
        vehicleName: json['devicename'] ?? json['vehicle_name'] ?? json['name'],
        deviceId: (json['deviceid'] ?? json['device_id'] ?? '').toString(),
        startTime: json['start_time'] ?? json['begin_time'],
        endTime: json['end_time'],
        distance: _toDouble(json['distance'] ?? json['mileage']),
        maxSpeed: _toDouble(json['max_speed']),
        avgSpeed: _toDouble(json['avg_speed']),
        duration: json['duration'] is int ? json['duration'] : null,
      );

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

class TripsResponse {
  final List<TripRecord> trips;
  final double totalDistance;
  final int totalTrips;

  const TripsResponse({
    required this.trips,
    required this.totalDistance,
    required this.totalTrips,
  });

  factory TripsResponse.fromJson(Map<String, dynamic> json) {
    final rawTrips = json['totaltrips'] ?? json['trips'] ?? [];
    return TripsResponse(
      trips: (rawTrips as List).map((t) => TripRecord.fromJson(t)).toList(),
      totalDistance:
          (json['totaldistance'] ?? json['total_distance'] ?? 0).toDouble(),
      totalTrips: rawTrips.length,
    );
  }
}

// lib/data/models/alarm_model.dart
class AlarmRecord {
  final String? vehicleName;
  final String? deviceId;
  final String? alarmType;
  final String? timestamp;
  final double? latitude;
  final double? longitude;
  final String? address;

  const AlarmRecord({
    this.vehicleName,
    this.deviceId,
    this.alarmType,
    this.timestamp,
    this.latitude,
    this.longitude,
    this.address,
  });

  factory AlarmRecord.fromJson(Map<String, dynamic> json) => AlarmRecord(
        vehicleName: json['devicename'] ?? json['vehicle_name'] ?? json['name'],
        deviceId: (json['deviceid'] ?? json['device_id'] ?? '').toString(),
        alarmType: json['alarm_type'] ?? json['type'],
        timestamp: json['timestamp'] ?? json['time'],
        latitude: _toDouble(json['lat'] ?? json['latitude']),
        longitude: _toDouble(json['lng'] ?? json['longitude']),
        address: json['address'],
      );

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

// lib/data/models/fuel_model.dart
class FuelRecord {
  final String? vehicleName;
  final String? deviceId;
  final double? fuelUsed;
  final double? fuelIn;
  final double? fuelOut;
  final String? timestamp;
  final double? distance;

  const FuelRecord({
    this.vehicleName,
    this.deviceId,
    this.fuelUsed,
    this.fuelIn,
    this.fuelOut,
    this.timestamp,
    this.distance,
  });

  factory FuelRecord.fromJson(Map<String, dynamic> json) => FuelRecord(
        vehicleName: json['devicename'] ?? json['vehicle_name'] ?? json['name'],
        deviceId: (json['deviceid'] ?? json['device_id'] ?? '').toString(),
        fuelUsed:
            _toDouble(json['fuel_used'] ?? json['fuel_l'] ?? json['fuel']),
        fuelIn: _toDouble(json['fuel_in']),
        fuelOut: _toDouble(json['fuel_out']),
        timestamp: json['timestamp'] ?? json['time'],
        distance: _toDouble(
            json['distance'] ?? json['total_distance_km'] ?? json['mileage']),
      );

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

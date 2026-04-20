// lib/data/repositories/vehicle_repository.dart
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:fleet_tracker/core/network/api_failure.dart';
import 'package:fleet_tracker/core/network/dio_client.dart';
import 'package:fleet_tracker/data/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepository(ref.read(dioProvider));
});

class VehicleRepository {
  final Dio _dio;
  VehicleRepository(this._dio);

  // Cache vehicle names for cross-referencing with positions
  final Map<String, String> _deviceNameCache = {};

  Future<Either<AppFailure, List<VehicleModel>>> getVehicles() async {
    try {
      final response = await _dio.get('/vehicles/');
      final data = response.data;
      final List raw = data['vehicles'] ?? data ?? [];
      final vehicles = raw.map((v) => VehicleModel.fromJson(v)).toList();

      // Cache device names
      for (final v in vehicles) {
        if (v.deviceId != null && v.deviceId!.isNotEmpty) {
          _deviceNameCache[v.deviceId!] = v.name;
        }
      }

      return Right(vehicles);
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<Either<AppFailure, List<PositionModel>>> getLivePositions() async {
    try {
      // Ensure we have vehicle names cached
      if (_deviceNameCache.isEmpty) {
        await getVehicles();
      }

      final response = await _dio.get('/location/live');
      final data = response.data;
      final List raw = data['positions'] ?? data ?? [];
      final positions = raw.map((p) {
        final pos = PositionModel.fromJson(p);
        // Attach vehicle name from cache
        final name = _deviceNameCache[pos.deviceId];
        if (name != null && (pos.vehicleName == null || pos.vehicleName!.isEmpty)) {
          return pos.withVehicleName(name);
        }
        return pos;
      }).toList();

      return Right(positions);
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<Either<AppFailure, PositionModel>> getLivePosition(String id) async {
    try {
      final response = await _dio.get('/location/live/$id');
      final pos = PositionModel.fromJson(response.data['position'] ?? response.data);
      final name = _deviceNameCache[pos.deviceId];
      if (name != null && (pos.vehicleName == null || pos.vehicleName!.isEmpty)) {
        return Right(pos.withVehicleName(name));
      }
      return Right(pos);
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  String? getDeviceName(String deviceId) => _deviceNameCache[deviceId];
}

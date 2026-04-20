// lib/data/repositories/reports_repository.dart
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:fleet_tracker/core/network/api_failure.dart';
import 'package:fleet_tracker/core/network/dio_client.dart';
import 'package:fleet_tracker/core/utils/date_utils.dart';
import 'package:fleet_tracker/data/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.read(dioProvider));
});

class ReportsRepository {
  final Dio _dio;
  ReportsRepository(this._dio);

  Future<Either<AppFailure, TripsResponse>> getTrips({
    required String deviceId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _dio.post('/reports/trips', data: {
        'device_id': deviceId,
        'begin_time': AppDateUtils.toApiDate(startDate),
        'end_time': AppDateUtils.toApiDate(endDate),
      });
      return Right(TripsResponse.fromJson(response.data));
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<Either<AppFailure, List<AlarmRecord>>> getAlarms({
    required List<String> deviceIds,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _dio.post('/reports/alarms', data: {
        'device_ids': deviceIds,
        'start_day': AppDateUtils.toApiDate(startDate),
        'end_day': AppDateUtils.toApiDate(endDate),
      });
      final data = response.data;
      final List raw = data['records'] ?? data ?? [];
      return Right(raw.map((a) => AlarmRecord.fromJson(a)).toList());
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }

  Future<Either<AppFailure, List<FuelRecord>>> getFuel({
    required List<String> deviceIds,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _dio.post('/reports/fuel', data: {
        'device_ids': deviceIds,
        'start_day': AppDateUtils.toApiDate(startDate),
        'end_day': AppDateUtils.toApiDate(endDate),
      });
      final data = response.data;
      final List raw = data['records'] ?? data ?? [];
      return Right(raw.map((f) => FuelRecord.fromJson(f)).toList());
    } on DioException catch (e) {
      return Left(dioErrorToFailure(e));
    }
  }
}

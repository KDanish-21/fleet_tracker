// lib/core/network/api_failure.dart
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

abstract class AppFailure extends Equatable {
  final String message;
  const AppFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'No internet connection']);
}

class ServerFailure extends AppFailure {
  final int? statusCode;
  const ServerFailure(super.message, [this.statusCode]);
  @override
  List<Object?> get props => [message, statusCode];
}

class AuthFailure extends AppFailure {
  const AuthFailure([super.message = 'Authentication failed']);
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message = 'An unknown error occurred']);
}

AppFailure dioErrorToFailure(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const NetworkFailure(
          'Server is waking up. Please try again in a moment.');
    case DioExceptionType.connectionError:
      return const NetworkFailure('No internet connection. Check your network.');
    case DioExceptionType.badResponse:
      final statusCode = e.response?.statusCode;
      final message = e.response?.data?['detail'] ??
          e.response?.data?['message'] ??
          'Server error';
      if (statusCode == 401) return AuthFailure(message.toString());
      return ServerFailure(message.toString(), statusCode);
    default:
      return const UnknownFailure();
  }
}

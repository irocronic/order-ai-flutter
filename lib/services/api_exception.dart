// lib/services/api_exception.dart

/// API'den dönen hataları temsil etmek için özel bir Exception sınıfı.
class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  ApiException(this.message, {this.code, this.statusCode});

  @override
  String toString() {
    return "ApiException(statusCode: $statusCode, code: $code, message: $message)";
  }
}
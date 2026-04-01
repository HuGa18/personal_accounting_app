import 'app_exception.dart';

/// 验证异常
/// 
/// 用于参数校验失败时抛出
/// 
/// 示例：
/// ```dart
/// if (amount <= 0) {
///   throw const ValidationException('交易金额必须大于0');
/// }
/// ```
class ValidationException extends AppException {
  const ValidationException(String message) : super(message, code: 'VALIDATION_ERROR');
}
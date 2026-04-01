import 'app_exception.dart';

/// 数据不存在异常
/// 
/// 用于查询数据不存在时抛出
/// 
/// 示例：
/// ```dart
/// final account = await repository.getById(id);
/// if (account == null) {
///   throw NotFoundException('账户不存在，ID：$id');
/// }
/// ```
class NotFoundException extends AppException {
  const NotFoundException(String message) : super(message, code: 'NOT_FOUND');
}
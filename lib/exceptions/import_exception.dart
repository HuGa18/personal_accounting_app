import 'app_exception.dart';

/// 导入异常
/// 
/// 用于账单导入失败时抛出
/// 
/// 示例：
/// ```dart
/// if (!['csv', 'pdf', 'xlsx'].contains(extension)) {
///   throw ImportException('不支持的文件格式：$extension');
/// }
/// ```
class ImportException extends AppException {
  const ImportException(String message) : super(message, code: 'IMPORT_ERROR');
}
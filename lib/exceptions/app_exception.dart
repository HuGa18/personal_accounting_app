/// 应用基础异常
/// 
/// 所有业务异常都应继承此类或使用其子类
class AppException implements Exception {
  /// 异常信息（中文）
  final String message;
  
  /// 异常代码（可选）
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => message;
}
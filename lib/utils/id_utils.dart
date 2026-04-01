import 'package:uuid/uuid.dart';

/// UUID生成工具类
class IdUtils {
  IdUtils._();

  static final _uuid = Uuid();

  /// 生成UUID v4
  static String generate() {
    return _uuid.v4();
  }

  /// 生成带前缀的UUID（前缀 + 8位UUID）
  static String generateWithPrefix(String prefix) {
    return '$prefix${_uuid.v4().substring(0, 8)}';
  }

  /// 生成带时间戳的UUID（前缀 + 时间戳 + 8位UUID）
  static String generateWithTimestamp(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$prefix${timestamp.toRadixString(36)}${_uuid.v4().substring(0, 8)}';
  }

  /// 生成短UUID（8位）
  static String generateShort() {
    return _uuid.v4().substring(0, 8);
  }

  /// 验证是否为有效的UUID格式
  static bool isValid(String id) {
    // UUID v4 格式：xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    // 其中 y 是 8, 9, a, 或 b
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(id);
  }

  /// 验证是否为有效的ID（UUID或带前缀的UUID）
  static bool isValidId(String id) {
    // 允许纯UUID或带前缀的UUID
    if (isValid(id)) {
      return true;
    }

    // 检查是否包含有效的UUID部分
    final parts = id.split('-');
    if (parts.length >= 5) {
      // 尝试提取UUID部分
      final possibleUuid = parts.sublist(parts.length - 5).join('-');
      return isValid(possibleUuid);
    }

    return false;
  }
}
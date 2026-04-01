/// 常量定义
class Constants {
  Constants._();

  /// 默认分页大小
  static const int defaultPageSize = 20;

  /// 最大分页大小
  static const int maxPageSize = 100;

  /// 批量操作大小限制
  static const int batchSize = 1000;

  /// 日期格式
  static const String dateFormat = 'yyyy-MM-dd';

  /// 日期时间格式
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';

  /// 月份格式
  static const String monthFormat = 'yyyy-MM';

  /// 金额小数位数
  static const int amountDecimalDigits = 2;

  /// 金额比较精度
  static const double amountEpsilon = 0.0001;

  /// 货币符号
  static const String currencySymbol = '¥';
}
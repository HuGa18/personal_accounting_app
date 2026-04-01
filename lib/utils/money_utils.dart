import 'constants.dart';

/// 金额格式化工具类
class MoneyUtils {
  MoneyUtils._();

  /// 格式化金额（带货币符号）
  static String format(double amount) {
    return '${Constants.currencySymbol}${amount.toStringAsFixed(Constants.amountDecimalDigits)}';
  }

  /// 格式化金额（不带货币符号）
  static String formatWithoutSymbol(double amount) {
    return amount.toStringAsFixed(Constants.amountDecimalDigits);
  }

  /// 格式化金额（带正负号）
  static String formatWithSign(double amount) {
    final sign = amount >= 0 ? '+' : '';
    return '$sign${Constants.currencySymbol}${amount.abs().toStringAsFixed(Constants.amountDecimalDigits)}';
  }

  /// 比较两个金额
  /// 返回值：0 表示相等，1 表示 a > b，-1 表示 a < b
  static int compare(double a, double b) {
    final diff = a - b;

    if (diff.abs() < Constants.amountEpsilon) {
      return 0;
    } else if (diff > 0) {
      return 1;
    } else {
      return -1;
    }
  }

  /// 判断两个金额是否相等
  static bool equals(double a, double b) {
    return compare(a, b) == 0;
  }

  /// 四舍五入到指定小数位
  static double round(double amount) {
    final factor = 10.0 * Constants.amountDecimalDigits;
    return (amount * factor).round() / factor;
  }

  /// 判断金额是否为零
  static bool isZero(double amount) {
    return equals(amount, 0);
  }

  /// 判断金额是否为正数
  static bool isPositive(double amount) {
    return compare(amount, 0) > 0;
  }

  /// 判断金额是否为负数
  static bool isNegative(double amount) {
    return compare(amount, 0) < 0;
  }

  /// 获取金额的绝对值
  static double abs(double amount) {
    return amount.abs();
  }

  /// 计算百分比
  static String formatPercentage(double part, double total) {
    if (isZero(total)) {
      return '0%';
    }
    final percentage = (part / total * 100).toStringAsFixed(1);
    return '$percentage%';
  }

  /// 解析金额字符串
  static double? parse(String amountStr) {
    // 移除货币符号和逗号
    final cleanStr = amountStr
        .replaceAll(Constants.currencySymbol, '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();

    return double.tryParse(cleanStr);
  }
}
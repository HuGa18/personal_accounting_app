import 'package:intl/intl.dart';
import 'constants.dart';

/// 日期格式化工具类
class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _dateFormat = DateFormat(Constants.dateFormat);
  static final DateFormat _dateTimeFormat = DateFormat(Constants.dateTimeFormat);
  static final DateFormat _monthFormat = DateFormat(Constants.monthFormat);

  /// 格式化日期 (yyyy-MM-dd)
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  /// 格式化日期时间 (yyyy-MM-dd HH:mm:ss)
  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  /// 格式化月份 (yyyy-MM)
  static String formatMonth(DateTime date) {
    return _monthFormat.format(date);
  }

  /// 解析日期字符串
  static DateTime parseDate(String dateStr) {
    return _dateFormat.parse(dateStr);
  }

  /// 解析日期时间字符串
  static DateTime parseDateTime(String dateTimeStr) {
    return _dateTimeFormat.parse(dateTimeStr);
  }

  /// 获取相对时间描述
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return '刚刚';
        }
        return '${difference.inMinutes}分钟前';
      }
      return '${difference.inHours}小时前';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return formatDate(dateTime);
    }
  }

  /// 获取今天的开始时间
  static DateTime getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 获取今天的结束时间
  static DateTime getEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  /// 获取本月的开始时间
  static DateTime getStartOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// 获取本月的结束时间
  static DateTime getEndOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);
  }

  /// 获取本周的开始时间（周一）
  static DateTime getStartOfWeek(DateTime date) {
    final weekday = date.weekday;
    return getStartOfDay(date.subtract(Duration(days: weekday - 1)));
  }

  /// 获取本周的结束时间（周日）
  static DateTime getEndOfWeek(DateTime date) {
    final weekday = date.weekday;
    return getEndOfDay(date.add(Duration(days: 7 - weekday)));
  }

  /// 判断是否是同一天
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 判断是否是今天
  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  /// 判断是否是昨天
  static bool isYesterday(DateTime date) {
    return isSameDay(date, DateTime.now().subtract(const Duration(days: 1)));
  }
}
/// 预算周期枚举
enum BudgetPeriod {
  weekly,
  monthly,
  yearly,
}

extension BudgetPeriodExtension on BudgetPeriod {
  /// 获取中文描述
  String get label {
    switch (this) {
      case BudgetPeriod.weekly:
        return '每周';
      case BudgetPeriod.monthly:
        return '每月';
      case BudgetPeriod.yearly:
        return '每年';
    }
  }

  /// 获取图标
  String get icon {
    switch (this) {
      case BudgetPeriod.weekly:
        return '📅';
      case BudgetPeriod.monthly:
        return '📆';
      case BudgetPeriod.yearly:
        return '🗓️';
    }
  }

  /// 获取周期天数
  int get days {
    switch (this) {
      case BudgetPeriod.weekly:
        return 7;
      case BudgetPeriod.monthly:
        return 30;
      case BudgetPeriod.yearly:
        return 365;
    }
  }

  /// 从字符串解析枚举
  static BudgetPeriod fromString(String value) {
    return BudgetPeriod.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BudgetPeriod.monthly,
    );
  }
}
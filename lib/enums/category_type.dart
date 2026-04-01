import 'package:flutter/material.dart';

/// 分类类型枚举
enum CategoryType {
  expense,
  income,
}

extension CategoryTypeExtension on CategoryType {
  /// 获取中文描述
  String get label {
    switch (this) {
      case CategoryType.expense:
        return '支出';
      case CategoryType.income:
        return '收入';
    }
  }

  /// 获取图标
  String get icon {
    switch (this) {
      case CategoryType.expense:
        return '💸';
      case CategoryType.income:
        return '💰';
    }
  }

  /// 获取颜色
  Color get color {
    switch (this) {
      case CategoryType.expense:
        return Colors.red;
      case CategoryType.income:
        return Colors.green;
    }
  }

  /// 从字符串解析枚举
  static CategoryType fromString(String value) {
    return CategoryType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CategoryType.expense,
    );
  }
}
import 'package:flutter/material.dart';

/// 交易类型枚举
enum TransactionType {
  expense,
  income,
  transfer,
}

extension TransactionTypeExtension on TransactionType {
  /// 获取中文描述
  String get label {
    switch (this) {
      case TransactionType.expense:
        return '支出';
      case TransactionType.income:
        return '收入';
      case TransactionType.transfer:
        return '转账';
    }
  }

  /// 获取图标
  String get icon {
    switch (this) {
      case TransactionType.expense:
        return '💸';
      case TransactionType.income:
        return '💰';
      case TransactionType.transfer:
        return '🔄';
    }
  }

  /// 获取颜色
  Color get color {
    switch (this) {
      case TransactionType.expense:
        return Colors.red;
      case TransactionType.income:
        return Colors.green;
      case TransactionType.transfer:
        return Colors.purple;
    }
  }

  /// 从字符串解析枚举
  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TransactionType.expense,
    );
  }
}
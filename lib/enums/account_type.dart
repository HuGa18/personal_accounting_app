import 'package:flutter/material.dart';

/// 账户类型枚举
enum AccountType {
  alipay,
  wechat,
  bankCard,
  cloudFlash,
  jdBaitiao,
  digitalRmb,
  cash,
  other,
}

extension AccountTypeExtension on AccountType {
  /// 获取中文描述
  String get label {
    switch (this) {
      case AccountType.alipay:
        return '支付宝';
      case AccountType.wechat:
        return '微信支付';
      case AccountType.bankCard:
        return '银行卡';
      case AccountType.cloudFlash:
        return '云闪付';
      case AccountType.jdBaitiao:
        return '京东白条';
      case AccountType.digitalRmb:
        return '数字人民币';
      case AccountType.cash:
        return '现金';
      case AccountType.other:
        return '其他';
    }
  }

  /// 获取图标
  String get icon {
    switch (this) {
      case AccountType.alipay:
        return '🟡';
      case AccountType.wechat:
        return '🟢';
      case AccountType.bankCard:
        return '💳';
      case AccountType.cloudFlash:
        return '📱';
      case AccountType.jdBaitiao:
        return '📦';
      case AccountType.digitalRmb:
        return '💴';
      case AccountType.cash:
        return '💵';
      case AccountType.other:
        return '📝';
    }
  }

  /// 获取颜色（十六进制字符串）
  String get colorHex {
    switch (this) {
      case AccountType.alipay:
        return '#1677FF';
      case AccountType.wechat:
        return '#07C160';
      case AccountType.bankCard:
        return '#6B7280';
      case AccountType.cloudFlash:
        return '#E53935';
      case AccountType.jdBaitiao:
        return '#E53935';
      case AccountType.digitalRmb:
        return '#FFB300';
      case AccountType.cash:
        return '#10B981';
      case AccountType.other:
        return '#6B7280';
    }
  }

  /// 获取颜色（Color对象）
  Color get color {
    switch (this) {
      case AccountType.alipay:
        return const Color(0xFF1677FF);
      case AccountType.wechat:
        return const Color(0xFF07C160);
      case AccountType.bankCard:
        return const Color(0xFF6B7280);
      case AccountType.cloudFlash:
        return const Color(0xFFE53935);
      case AccountType.jdBaitiao:
        return const Color(0xFFE53935);
      case AccountType.digitalRmb:
        return const Color(0xFFFFB300);
      case AccountType.cash:
        return const Color(0xFF10B981);
      case AccountType.other:
        return const Color(0xFF6B7280);
    }
  }

  /// 从字符串解析枚举
  static AccountType fromString(String value) {
    return AccountType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AccountType.other,
    );
  }
}
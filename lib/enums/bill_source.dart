import 'package:flutter/material.dart';

/// 账单来源枚举
enum BillSource {
  alipay,
  wechat,
  bankCard,
  cloudFlash,
  jdBaitiao,
  digitalRmb,
  manual,
}

extension BillSourceExtension on BillSource {
  /// 获取中文描述
  String get label {
    switch (this) {
      case BillSource.alipay:
        return '支付宝';
      case BillSource.wechat:
        return '微信支付';
      case BillSource.bankCard:
        return '银行卡';
      case BillSource.cloudFlash:
        return '云闪付';
      case BillSource.jdBaitiao:
        return '京东白条';
      case BillSource.digitalRmb:
        return '数字人民币';
      case BillSource.manual:
        return '手动录入';
    }
  }

  /// 获取图标
  String get icon {
    switch (this) {
      case BillSource.alipay:
        return '🟡';
      case BillSource.wechat:
        return '🟢';
      case BillSource.bankCard:
        return '💳';
      case BillSource.cloudFlash:
        return '📱';
      case BillSource.jdBaitiao:
        return '📦';
      case BillSource.digitalRmb:
        return '💴';
      case BillSource.manual:
        return '✏️';
    }
  }

  /// 获取颜色
  Color get color {
    switch (this) {
      case BillSource.alipay:
        return const Color(0xFF1677FF);
      case BillSource.wechat:
        return const Color(0xFF07C160);
      case BillSource.bankCard:
        return const Color(0xFF6B7280);
      case BillSource.cloudFlash:
        return const Color(0xFFE53935);
      case BillSource.jdBaitiao:
        return const Color(0xFFE53935);
      case BillSource.digitalRmb:
        return const Color(0xFFFFB300);
      case BillSource.manual:
        return const Color(0xFF10B981);
    }
  }

  /// 是否可导入
  bool get isImportable {
    return this != BillSource.manual;
  }

  /// 从字符串解析枚举
  static BillSource fromString(String value) {
    return BillSource.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BillSource.manual,
    );
  }
}
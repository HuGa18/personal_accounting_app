import 'package:flutter/material.dart';

/// 空状态组件
/// 用于展示无数据时的提示界面
class EmptyState extends StatelessWidget {
  /// 图标
  final IconData? icon;
  
  /// 标题
  final String? title;
  
  /// 描述文本
  final String? message;
  
  /// 操作按钮文本
  final String? actionText;
  
  /// 操作按钮回调
  final VoidCallback? onAction;
  
  /// 自定义图标大小
  final double iconSize;
  
  /// 自定义图标颜色
  final Color? iconColor;

  const EmptyState({
    super.key,
    this.icon,
    this.title,
    this.message,
    this.actionText,
    this.onAction,
    this.iconSize = 64,
    this.iconColor,
  });

  /// 创建交易列表空状态
  const EmptyState.transactions({
    super.key,
    this.title = '暂无交易记录',
    this.message,
    this.actionText,
    this.onAction,
    this.iconSize = 64,
    this.iconColor,
  }) : icon = Icons.receipt_long_outlined;

  /// 创建账户列表空状态
  const EmptyState.accounts({
    super.key,
    this.title = '暂无账户',
    this.message,
    this.actionText,
    this.onAction,
    this.iconSize = 64,
    this.iconColor,
  }) : icon = Icons.account_balance_wallet_outlined;

  /// 创建分类列表空状态
  const EmptyState.categories({
    super.key,
    this.title = '暂无分类',
    this.message,
    this.actionText,
    this.onAction,
    this.iconSize = 64,
    this.iconColor,
  }) : icon = Icons.category_outlined;

  /// 创建预算列表空状态
  const EmptyState.budgets({
    super.key,
    this.title = '暂无预算',
    this.message,
    this.actionText,
    this.onAction,
    this.iconSize = 64,
    this.iconColor,
  }) : icon = Icons.savings_outlined;

  /// 创建搜索结果空状态
  const EmptyState.search({
    super.key,
    this.title = '未找到相关结果',
    this.message = '请尝试其他关键词',
    this.actionText,
    this.onAction,
    this.iconSize = 64,
    this.iconColor,
  }) : icon = Icons.search_off;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: iconSize,
                color: iconColor ?? Colors.grey[400],
              ),
              const SizedBox(height: 16),
            ],
            if (title != null) ...[
              Text(
                title!,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            if (message != null) ...[
              Text(
                message!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            if (actionText != null && onAction != null)
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionText!),
              ),
          ],
        ),
      ),
    );
  }
}
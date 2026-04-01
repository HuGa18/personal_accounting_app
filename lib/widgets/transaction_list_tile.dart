import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../utils/money_utils.dart';
import '../utils/date_utils.dart';
import '../enums/transaction_type.dart';

/// 交易列表项组件
/// 用于展示单条交易记录的简要信息
class TransactionListTile extends StatelessWidget {
  /// 交易记录数据
  final Transaction transaction;
  
  /// 点击回调
  final VoidCallback? onTap;
  
  /// 是否显示日期
  final bool showDate;
  
  /// 自定义图标
  final Widget? leadingIcon;

  const TransactionListTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.showDate = false,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == 'expense';
    final isIncome = transaction.type == 'income';
    final amountColor = isExpense ? Colors.red : (isIncome ? Colors.green : Colors.purple);
    final amountPrefix = isExpense ? '-' : '+';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: leadingIcon ?? _buildDefaultLeading(amountColor, isExpense),
      title: Text(
        transaction.merchantName ?? '未知商户',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: _buildSubtitle(),
      trailing: Text(
        '$amountPrefix${MoneyUtils.format(transaction.amount)}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: amountColor,
        ),
      ),
      onTap: onTap,
    );
  }

  /// 构建默认前导图标
  Widget _buildDefaultLeading(Color color, bool isExpense) {
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(
        isExpense ? Icons.arrow_upward : Icons.arrow_downward,
        color: color,
        size: 20,
      ),
    );
  }

  /// 构建副标题
  Widget? _buildSubtitle() {
    final timeStr = _formatTime(transaction.transactionDate);
    final parts = <String>[];
    
    if (showDate) {
      parts.add(DateUtils.formatDate(transaction.transactionDate));
    }
    parts.add(timeStr);
    
    final timeText = parts.join(' ');
    
    if (transaction.description != null && transaction.description!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timeText,
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            transaction.description!,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }
    
    return Text(
      timeText,
      style: const TextStyle(fontSize: 12),
    );
  }

  /// 格式化时间
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
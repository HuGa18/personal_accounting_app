import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../utils/date_utils.dart';
import '../../utils/money_utils.dart';

/// 设置页面
/// 包含数据概览、账户管理、预算设置、分类管理、数据导出、备份恢复等功能入口
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final budgetsAsync = ref.watch(budgetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // 数据概览卡片
          _buildDataOverviewCard(
            context,
            accountsAsync,
            transactionsAsync,
            categoriesAsync,
            budgetsAsync,
          ),
          const SizedBox(height: 16),

          // 功能设置分组
          _buildSettingsSection(
            context,
            title: '数据管理',
            items: [
              _SettingsItem(
                icon: Icons.account_balance_wallet,
                iconColor: Colors.blue,
                title: '账户管理',
                subtitle: '管理支付账户信息',
                onTap: () => _showComingSoon(context, '账户管理'),
              ),
              _SettingsItem(
                icon: Icons.category,
                iconColor: Colors.orange,
                title: '分类管理',
                subtitle: '自定义收支分类',
                onTap: () => _showComingSoon(context, '分类管理'),
              ),
              _SettingsItem(
                icon: Icons.account_balance,
                iconColor: Colors.green,
                title: '预算设置',
                subtitle: '设置每月预算额度',
                onTap: () => _showComingSoon(context, '预算设置'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSettingsSection(
            context,
            title: '数据备份',
            items: [
              _SettingsItem(
                icon: Icons.file_download,
                iconColor: Colors.purple,
                title: '数据导出',
                subtitle: '导出CSV、Excel或PDF格式',
                onTap: () => _showComingSoon(context, '数据导出'),
              ),
              _SettingsItem(
                icon: Icons.backup,
                iconColor: Colors.teal,
                title: '备份与恢复',
                subtitle: '备份或恢复应用数据',
                onTap: () => _showComingSoon(context, '备份与恢复'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSettingsSection(
            context,
            title: '应用设置',
            items: [
              _SettingsItem(
                icon: Icons.palette,
                iconColor: Colors.indigo,
                title: '主题设置',
                subtitle: '深色/浅色主题切换',
                onTap: () => _showComingSoon(context, '主题设置'),
              ),
              _SettingsItem(
                icon: Icons.lock,
                iconColor: Colors.red,
                title: '应用锁',
                subtitle: '设置密码保护',
                onTap: () => _showComingSoon(context, '应用锁'),
              ),
              _SettingsItem(
                icon: Icons.info_outline,
                iconColor: Colors.grey,
                title: '关于',
                subtitle: '版本信息与帮助',
                onTap: () => _showAboutDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 构建数据概览卡片
  Widget _buildDataOverviewCard(
    BuildContext context,
    AsyncValue<List> accountsAsync,
    AsyncValue<List> transactionsAsync,
    AsyncValue<List> categoriesAsync,
    AsyncValue<List> budgetsAsync,
  ) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '数据概览',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewItem(
                    context,
                    icon: Icons.account_balance_wallet,
                    label: '账户',
                    valueAsync: accountsAsync,
                  ),
                ),
                Expanded(
                  child: _buildOverviewItem(
                    context,
                    icon: Icons.receipt_long,
                    label: '交易',
                    valueAsync: transactionsAsync,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewItem(
                    context,
                    icon: Icons.category,
                    label: '分类',
                    valueAsync: categoriesAsync,
                  ),
                ),
                Expanded(
                  child: _buildOverviewItem(
                    context,
                    icon: Icons.account_balance,
                    label: '预算',
                    valueAsync: budgetsAsync,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // 记账天数和数据跨度
            transactionsAsync.when(
              data: (transactions) => _buildDateRangeInfo(context, transactions),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建概览单项
  Widget _buildOverviewItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required AsyncValue<List> valueAsync,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              valueAsync.when(
                data: (data) => Text(
                  '${data.length}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                loading: () => const Text('-'),
                error: (_, __) => const Text('-'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建日期范围信息
  Widget _buildDateRangeInfo(BuildContext context, List transactions) {
    if (transactions.isEmpty) {
      return Row(
        children: [
          Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '记账天数: 0天',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      );
    }

    // 计算记账天数和数据跨度
    final dates = transactions
        .map((t) => DateTime(
              t.transactionDate.year,
              t.transactionDate.month,
              t.transactionDate.day,
            ))
        .toSet()
        .toList();
    dates.sort();

    final firstDate = dates.first;
    final lastDate = dates.last;
    final daysCount = dates.length;
    final spanDays = lastDate.difference(firstDate).inDays + 1;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '记账天数: $daysCount天',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.date_range, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '数据跨度: $spanDays天',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              '首条记录: ${AppDateUtils.formatDate(firstDate)} ~ 末条记录: ${AppDateUtils.formatDate(lastDate)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建设置分组
  Widget _buildSettingsSection(
    BuildContext context, {
    required String title,
    required List<_SettingsItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 1,
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.icon, color: item.iconColor, size: 20),
                    ),
                    title: Text(item.title),
                    subtitle: Text(
                      item.subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: item.onTap,
                  ),
                  if (index < items.length - 1)
                    const Divider(height: 1, indent: 56),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 显示即将推出提示
  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature功能开发中，敬请期待'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 显示关于对话框
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '个人全渠道记账应用',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('版本: 1.0.0'),
            SizedBox(height: 16),
            Text('一款简洁高效的个人记账应用，支持多渠道账单导入、智能分类、统计分析等功能。'),
            SizedBox(height: 16),
            Text('技术栈: Flutter + Riverpod + SQLite'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

/// 设置项数据类
class _SettingsItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/pages.dart';

/// 应用路由配置
/// 使用 go_router 进行路由管理
final GoRouter appRouter = GoRouter(
  routes: [
    // 主页面壳（包含底部导航栏）
    ShellRoute(
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        // 首页
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const HomePage(),
        ),
        // 交易列表
        GoRoute(
          path: '/transactions',
          name: 'transactions',
          builder: (context, state) => const TransactionListPage(),
        ),
        // 统计分析
        GoRoute(
          path: '/statistics',
          name: 'statistics',
          builder: (context, state) => const StatisticsPage(),
        ),
        // 设置
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
    // 添加交易（独立页面，不在底部导航栏）
    GoRoute(
      path: '/transactions/add',
      name: 'transaction-add',
      builder: (context, state) => const TransactionFormPage(),
    ),
    // 编辑交易
    GoRoute(
      path: '/transactions/edit/:id',
      name: 'transaction-edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return TransactionFormPage(transactionId: id);
      },
    ),
    // 账单导入
    GoRoute(
      path: '/import',
      name: 'import',
      builder: (context, state) => const ImportPage(),
    ),
  ],
  // 错误处理
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(
      title: const Text('页面未找到'),
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            '页面未找到: ${state.error}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('返回首页'),
          ),
        ],
      ),
    ),
  ),
  // 初始位置
  initialLocation: '/',
  // 调试日志
  debugLogDiagnostics: true,
);
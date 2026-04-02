import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'router/router.dart';
import 'exceptions/exceptions.dart';

/// 应用配置类
/// 包含主题配置、全局异常处理等
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return MaterialApp(
        title: '个人记账',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const WebUnsupportedPage(),
      );
    }
    
    return MaterialApp.router(
      title: '个人记账',
      debugShowCheckedModeBanner: false,
      // 路由配置
      routerConfig: appRouter,
      // 浅色主题
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 4,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      // 深色主题
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 4,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
        ),
      ),
      // 跟随系统主题
      themeMode: ThemeMode.system,
      // 构建器：添加全局错误捕获
      builder: (context, child) {
        return GlobalErrorWidget(
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}

/// 全局错误捕获 Widget
/// 捕获子组件树中的错误并显示友好的错误页面
class GlobalErrorWidget extends StatefulWidget {
  final Widget child;

  const GlobalErrorWidget({
    super.key,
    required this.child,
  });

  @override
  State<GlobalErrorWidget> createState() => _GlobalErrorWidgetState();
}

class _GlobalErrorWidgetState extends State<GlobalErrorWidget> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    // 捕获 Flutter 框架错误
    FlutterError.onError = (FlutterErrorDetails details) {
      setState(() {
        _error = details.exception;
      });
      // 同时打印到控制台
      FlutterError.presentError(details);
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorPage();
    }
    return widget.child;
  }

  Widget _buildErrorPage() {
    String errorMessage = '发生未知错误';

    if (_error is AppException) {
      final appException = _error as AppException;
      errorMessage = appException.message;
    } else if (_error is FlutterError) {
      errorMessage = '应用错误: ${_error.toString()}';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('出错了'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                  });
                  context.go('/');
                },
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 主页面壳，包含底部导航栏
class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({
    super.key,
    required this.child,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // 导航项配置
  static const _navigationItems = [
    _NavigationItem(
      path: '/',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: '首页',
    ),
    _NavigationItem(
      path: '/transactions',
      icon: Icons.list_outlined,
      selectedIcon: Icons.list,
      label: '明细',
    ),
    _NavigationItem(
      path: '/statistics',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: '统计',
    ),
    _NavigationItem(
      path: '/settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: '设置',
    ),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
    context.go(_navigationItems[index].path);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 根据当前路由更新选中索引
    final location = GoRouterState.of(context).matchedLocation;
    final index = _navigationItems.indexWhere(
      (item) => location == item.path,
    );
    if (index != -1 && index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: _navigationItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}

/// 导航项配置
class _NavigationItem {
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavigationItem({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Web 平台不支持页面
class WebUnsupportedPage extends StatelessWidget {
  const WebUnsupportedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.phone_android,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                '个人记账应用',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '此应用需要在移动设备上运行',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '请下载 Android 或 iOS 版本',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // 可以添加下载链接
                },
                icon: const Icon(Icons.download),
                label: const Text('下载应用'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

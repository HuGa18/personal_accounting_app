import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'database/db.dart';

void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化数据库
  await DatabaseHelper.instance.database;

  // 配置全局异常处理
  _setupErrorHandling();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

/// 配置全局异常处理
void _setupErrorHandling() {
  // 捕获 Flutter 框架错误
  FlutterError.onError = (FlutterErrorDetails details) {
    // 打印到控制台
    FlutterError.presentError(details);
    // 可以在这里上报错误到日志系统
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  // 捕获 Dart 异步错误
  PlatformDispatcher.instance.onError = (error, stack) {
    // 打印到控制台
    debugPrint('Platform Error: $error');
    debugPrint('Stack trace: $stack');
    // 返回 true 表示已处理
    return true;
  };

  // 捕获未处理的异步错误
  runZonedGuarded(() {
    // 应用启动
  }, (error, stack) {
    // 打印到控制台
    debugPrint('Uncaught Error: $error');
    debugPrint('Stack trace: $stack');
  });
}

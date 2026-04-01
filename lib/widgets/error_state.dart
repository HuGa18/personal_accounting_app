import 'package:flutter/material.dart';

/// 错误状态组件
/// 用于展示错误信息界面
class ErrorState extends StatelessWidget {
  /// 错误信息
  final String? message;
  
  /// 重试按钮文本
  final String? retryText;
  
  /// 重试回调
  final VoidCallback? onRetry;
  
  /// 自定义图标
  final IconData? icon;
  
  /// 自定义标题
  final String? title;

  const ErrorState({
    super.key,
    this.message,
    this.retryText,
    this.onRetry,
    this.icon,
    this.title,
  });

  /// 创建网络错误状态
  const ErrorState.network({
    super.key,
    this.message = '网络连接失败，请检查网络设置',
    this.retryText = '重试',
    this.onRetry,
  }) : icon = Icons.wifi_off,
       title = '网络错误';

  /// 创建加载错误状态
  const ErrorState.loading({
    super.key,
    this.message = '数据加载失败',
    this.retryText = '重新加载',
    this.onRetry,
  }) : icon = Icons.error_outline,
       title = '加载失败';

  /// 创建通用错误状态
  const ErrorState.general({
    super.key,
    this.message = '发生错误，请稍后重试',
    this.retryText = '重试',
    this.onRetry,
  }) : icon = Icons.error_outline,
       title = '出错了';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              title ?? '出错了',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryText ?? '重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
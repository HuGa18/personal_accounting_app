import 'package:flutter/material.dart';

/// 加载状态组件
/// 用于展示数据加载中的界面
class LoadingState extends StatelessWidget {
  /// 提示文本
  final String? message;
  
  /// 进度值（0-1），null表示不确定进度
  final double? progress;
  
  /// 是否使用线性进度条
  final bool linear;
  
  /// 自定义加载动画
  final Widget? customIndicator;

  const LoadingState({
    super.key,
    this.message,
    this.progress,
    this.linear = false,
    this.customIndicator,
  });

  /// 创建全屏加载状态
  const LoadingState.fullScreen({
    super.key,
    this.message = '加载中...',
    this.progress,
    this.linear = false,
    this.customIndicator,
  });

  /// 创建内联加载状态
  const LoadingState.inline({
    super.key,
    this.message,
    this.progress,
    this.linear = false,
    this.customIndicator,
  });

  @override
  Widget build(BuildContext context) {
    if (linear) {
      return _buildLinearLoading();
    }
    return _buildCircularLoading();
  }

  /// 构建圆形进度指示器
  Widget _buildCircularLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          customIndicator ??
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 3,
              ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建线性进度指示器
  Widget _buildLinearLoading() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 4,
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }
}
import 'constants.dart';

/// 批量操作工具类
class BatchUtils {
  BatchUtils._();

  /// 分批处理数据
  /// [items] 待处理的数据列表
  /// [processor] 处理函数
  /// [batchSize] 每批大小，默认1000
  static Future<void> processInBatches<T>(
    List<T> items,
    Future<void> Function(List<T>) processor, {
    int batchSize = Constants.batchSize,
  }) async {
    for (int i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      final batch = items.sublist(i, end);
      await processor(batch);
    }
  }

  /// 将数据分割成批次
  /// [items] 待分割的数据列表
  /// [batchSize] 每批大小，默认1000
  static List<List<T>> splitIntoBatches<T>(
    List<T> items, {
    int batchSize = Constants.batchSize,
  }) {
    final batches = <List<T>>[];
    for (int i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      batches.add(items.sublist(i, end));
    }
    return batches;
  }

  /// 分批处理数据并收集结果
  /// [items] 待处理的数据列表
  /// [processor] 处理函数，返回处理结果
  /// [batchSize] 每批大小，默认1000
  static Future<List<R>> processInBatchesWithResult<T, R>(
    List<T> items,
    Future<List<R>> Function(List<T>) processor, {
    int batchSize = Constants.batchSize,
  }) async {
    final results = <R>[];
    for (int i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      final batch = items.sublist(i, end);
      final batchResults = await processor(batch);
      results.addAll(batchResults);
    }
    return results;
  }

  /// 检查批量大小是否超过限制
  static bool isWithinLimit(int count, {int? batchSize}) {
    final limit = batchSize ?? Constants.batchSize;
    return count <= limit;
  }

  /// 获取批次数
  static int getBatchCount(int totalCount, {int? batchSize}) {
    final size = batchSize ?? Constants.batchSize;
    return (totalCount + size - 1) ~/ size;
  }

  /// 获取指定批次的数据范围
  static (int start, int end) getBatchRange(
    int batchIndex,
    int totalCount, {
    int? batchSize,
  }) {
    final size = batchSize ?? Constants.batchSize;
    final start = batchIndex * size;
    final end = (start + size < totalCount) ? start + size : totalCount;
    return (start, end);
  }
}
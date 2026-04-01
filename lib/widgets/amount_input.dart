import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/money_utils.dart';

/// 金额输入框组件
/// 提供格式化的金额输入功能
class AmountInput extends StatefulWidget {
  /// 控制器
  final TextEditingController? controller;
  
  /// 初始金额
  final double? initialValue;
  
  /// 标签文本
  final String? label;
  
  /// 提示文本
  final String? hint;
  
  /// 是否必填
  final bool required;
  
  /// 是否启用
  final bool enabled;
  
  /// 最小值
  final double? minValue;
  
  /// 最大值
  final double? maxValue;
  
  /// 值变化回调
  final ValueChanged<double>? onChanged;
  
  /// 是否显示货币符号
  final bool showCurrencySymbol;

  const AmountInput({
    super.key,
    this.controller,
    this.initialValue,
    this.label,
    this.hint,
    this.required = false,
    this.enabled = true,
    this.minValue,
    this.maxValue,
    this.onChanged,
    this.showCurrencySymbol = true,
  });

  @override
  State<AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<AmountInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!.toStringAsFixed(Constants.amountDecimalDigits);
    }
  }

  @override
  void didUpdateWidget(AmountInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller == null) {
        _controller.dispose();
      }
      _controller = widget.controller ?? TextEditingController();
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label ?? '金额',
        hintText: widget.hint ?? '请输入金额',
        prefixText: widget.showCurrencySymbol ? Constants.currencySymbol : null,
        border: const OutlineInputBorder(),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: widget.enabled
                    ? () {
                        _controller.clear();
                        widget.onChanged?.call(0);
                        setState(() {});
                      }
                    : null,
              )
            : null,
      ),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: false,
      ),
      enabled: widget.enabled,
      textAlign: TextAlign.right,
      onChanged: (value) {
        final amount = double.tryParse(value);
        if (amount != null) {
          widget.onChanged?.call(amount);
        }
        setState(() {});
      },
      validator: _validate,
      inputFormatters: [
        // 只允许输入数字和小数点
        _AmountInputFormatter(),
      ],
    );
  }

  /// 验证输入
  String? _validate(String? value) {
    if (value == null || value.isEmpty) {
      if (widget.required) {
        return '请输入金额';
      }
      return null;
    }

    final amount = double.tryParse(value);
    if (amount == null) {
      return '请输入有效金额';
    }

    if (widget.minValue != null && amount < widget.minValue!) {
      return '金额不能小于${MoneyUtils.format(widget.minValue!)}';
    }

    if (widget.maxValue != null && amount > widget.maxValue!) {
      return '金额不能大于${MoneyUtils.format(widget.maxValue!)}';
    }

    // 默认要求金额大于0
    if (amount <= 0) {
      return '金额必须大于0';
    }

    return null;
  }
}

/// 金额输入格式化器
class _AmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 允许空值
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // 检查是否是有效的数字格式
    final text = newValue.text;
    
    // 只允许数字和小数点
    if (!RegExp(r'^[\d.]+$').hasMatch(text)) {
      return oldValue;
    }

    // 检查小数点数量
    final dotCount = '.'.allMatches(text).length;
    if (dotCount > 1) {
      return oldValue;
    }

    // 检查小数位数
    if (dotCount == 1) {
      final parts = text.split('.');
      if (parts.length == 2 && parts[1].length > Constants.amountDecimalDigits) {
        return oldValue;
      }
    }

    // 不允许以多个0开头（除非是0或0.x）
    if (text.length > 1 && text.startsWith('0') && !text.startsWith('0.')) {
      return oldValue;
    }

    return newValue;
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../providers/providers.dart';
import '../enums/category_type.dart';

/// 分类选择器组件
/// 用于选择支出或收入分类
class CategorySelector extends ConsumerStatefulWidget {
  /// 当前选中的分类ID
  final String? selectedCategoryId;
  
  /// 选择变化回调
  final ValueChanged<String?> onChanged;
  
  /// 分类类型（expense/income）
  final String categoryType;
  
  /// 是否显示标签
  final String? label;
  
  /// 是否必填
  final bool required;
  
  /// 是否启用
  final bool enabled;
  
  /// 是否显示为下拉框
  final bool asDropdown;

  const CategorySelector({
    super.key,
    this.selectedCategoryId,
    required this.onChanged,
    this.categoryType = 'expense',
    this.label,
    this.required = false,
    this.enabled = true,
    this.asDropdown = true,
  });

  @override
  ConsumerState<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends ConsumerState<CategorySelector> {
  String? _selectedParentId;
  String? _selectedSubId;

  @override
  void initState() {
    super.initState();
    _initSelection();
  }

  @override
  void didUpdateWidget(CategorySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategoryId != widget.selectedCategoryId) {
      _initSelection();
    }
  }

  /// 初始化选择状态
  void _initSelection() {
    if (widget.selectedCategoryId == null) {
      _selectedParentId = null;
      _selectedSubId = null;
      return;
    }
    
    // 需要异步获取分类信息来判断是父分类还是子分类
    _loadCategoryInfo();
  }

  /// 加载分类信息
  Future<void> _loadCategoryInfo() async {
    final categories = await ref.read(categoriesProvider.future);
    final category = categories.where((c) => c.id == widget.selectedCategoryId).firstOrNull;
    
    if (category != null) {
      if (category.parentId == null) {
        // 是父分类
        setState(() {
          _selectedParentId = category.id;
          _selectedSubId = null;
        });
      } else {
        // 是子分类
        setState(() {
          _selectedParentId = category.parentId;
          _selectedSubId = category.id;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        final filteredCategories = categories
            .where((c) => c.type == widget.categoryType)
            .toList();
        
        // 分离父分类和子分类
        final parentCategories = filteredCategories
            .where((c) => c.parentId == null)
            .toList();
        
        if (widget.asDropdown) {
          return _buildDropdownSelector(parentCategories, filteredCategories);
        } else {
          return _buildChipSelector(parentCategories, filteredCategories);
        }
      },
      loading: () => _buildLoading(),
      error: (error, stack) => _buildError(error),
    );
  }

  /// 构建下拉选择器
  Widget _buildDropdownSelector(
    List<Category> parentCategories,
    List<Category> allCategories,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 父分类选择
        DropdownButtonFormField<String>(
          value: _selectedParentId,
          decoration: InputDecoration(
            labelText: widget.label ?? '分类',
            border: const OutlineInputBorder(),
          ),
          items: parentCategories
              .map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name),
                  ))
              .toList(),
          onChanged: widget.enabled
              ? (value) {
                  setState(() {
                    _selectedParentId = value;
                    _selectedSubId = null;
                  });
                  widget.onChanged(value);
                }
              : null,
          validator: widget.required
              ? (value) {
                  if (value == null) {
                    return '请选择分类';
                  }
                  return null;
                }
              : null,
        ),
        
        // 子分类选择（如果有的话）
        if (_selectedParentId != null) ...[
          const SizedBox(height: 12),
          _buildSubCategoryDropdown(allCategories),
        ],
      ],
    );
  }

  /// 构建子分类下拉框
  Widget _buildSubCategoryDropdown(List<Category> allCategories) {
    final subCategories = allCategories
        .where((c) => c.parentId == _selectedParentId)
        .toList();
    
    if (subCategories.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return DropdownButtonFormField<String>(
      value: _selectedSubId,
      decoration: const InputDecoration(
        labelText: '子分类',
        border: OutlineInputBorder(),
      ),
      items: subCategories
          .map((c) => DropdownMenuItem(
                value: c.id,
                child: Text(c.name),
              ))
          .toList(),
      onChanged: widget.enabled
          ? (value) {
              setState(() => _selectedSubId = value);
              widget.onChanged(value);
            }
          : null,
    );
  }

  /// 构建Chip选择器
  Widget _buildChipSelector(
    List<Category> parentCategories,
    List<Category> allCategories,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: parentCategories.map((c) {
            final isSelected = _selectedParentId == c.id;
            return FilterChip(
              label: Text(c.name),
              selected: isSelected,
              onSelected: widget.enabled
                  ? (selected) {
                      setState(() {
                        _selectedParentId = selected ? c.id : null;
                        _selectedSubId = null;
                      });
                      widget.onChanged(selected ? c.id : null);
                    }
                  : null,
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 构建加载状态
  Widget _buildLoading() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: widget.label ?? '分类',
        border: const OutlineInputBorder(),
        suffixIcon: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      enabled: false,
    );
  }

  /// 构建错误状态
  Widget _buildError(Object error) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: widget.label ?? '分类',
        border: const OutlineInputBorder(),
        errorText: '加载失败',
      ),
      enabled: false,
    );
  }
}
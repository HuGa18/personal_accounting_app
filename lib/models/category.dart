class Category {
  final String id;
  final String name;
  final String? icon;
  final String? color;
  final String? parentId;
  final String type;
  final List<String> keywords;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  Category({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.parentId,
    required this.type,
    this.keywords = const [],
    this.isSystem = true,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'parent_id': parentId,
      'type': type,
      'keywords': keywords.join(','),
      'is_system': isSystem ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Category.fromJson(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      color: map['color'],
      parentId: map['parent_id'],
      type: map['type'],
      keywords: map['keywords'] != null && map['keywords'].toString().isNotEmpty
          ? map['keywords'].toString().split(',')
          : [],
      isSystem: (map['is_system'] ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : DateTime.now(),
      isDeleted: (map['is_deleted'] ?? 0) == 1,
    );
  }

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    String? parentId,
    String? type,
    List<String>? keywords,
    bool? isSystem,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      parentId: parentId ?? this.parentId,
      type: type ?? this.type,
      keywords: keywords ?? this.keywords,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
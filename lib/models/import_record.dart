class ImportRecord {
  final String id;
  final String source;
  final String? externalId;
  final DateTime importDate;
  final int? recordCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  ImportRecord({
    required this.id,
    required this.source,
    this.externalId,
    required this.importDate,
    this.recordCount,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source,
      'external_id': externalId,
      'import_date': importDate.toIso8601String(),
      'record_count': recordCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory ImportRecord.fromJson(Map<String, dynamic> map) {
    return ImportRecord(
      id: map['id'],
      source: map['source'],
      externalId: map['external_id'],
      importDate: DateTime.parse(map['import_date']),
      recordCount: map['record_count'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : DateTime.now(),
      isDeleted: (map['is_deleted'] ?? 0) == 1,
    );
  }

  ImportRecord copyWith({
    String? id,
    String? source,
    String? externalId,
    DateTime? importDate,
    int? recordCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return ImportRecord(
      id: id ?? this.id,
      source: source ?? this.source,
      externalId: externalId ?? this.externalId,
      importDate: importDate ?? this.importDate,
      recordCount: recordCount ?? this.recordCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
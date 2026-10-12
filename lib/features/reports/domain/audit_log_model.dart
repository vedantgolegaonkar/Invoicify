import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class AuditLogModel extends Equatable {
  final String id;
  final String module;
  final String action;
  final String recordId;
  final String description;
  final DateTime timestamp;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  const AuditLogModel({
    required this.id,
    required this.module,
    required this.action,
    required this.recordId,
    required this.description,
    required this.timestamp,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  AuditLogModel copyWith({
    String? id,
    String? module,
    String? action,
    String? recordId,
    String? description,
    DateTime? timestamp,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return AuditLogModel(
      id: id ?? this.id,
      module: module ?? this.module,
      action: action ?? this.action,
      recordId: recordId ?? this.recordId,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'module': module,
      'action': action,
      'recordId': recordId,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  factory AuditLogModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AuditLogModel(
      id: documentId,
      module: map['module'] ?? '',
      action: map['action'] ?? '',
      recordId: map['recordId'] ?? '',
      description: map['description'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: map['isDeleted'] ?? false,
      deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory AuditLogModel.fromJson(Map<String, dynamic> source, String documentId) => 
      AuditLogModel.fromMap(source, documentId);

  @override
  List<Object?> get props => [
        id,
        module,
        action,
        recordId,
        description,
        timestamp,
        createdAt,
        updatedAt,
        isDeleted,
        deletedAt,
      ];
}

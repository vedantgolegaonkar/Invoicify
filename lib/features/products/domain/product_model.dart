import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ProductModel extends Equatable {
  final String id;
  final String name;
  final String? hsnCode;
  final double cgst;
  final double sgst;
  final double igst;
  final double currentStock;
  final double minimumStock;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  const ProductModel({
    required this.id,
    required this.name,
    this.hsnCode,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.currentStock,
    required this.minimumStock,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  ProductModel copyWith({
    String? id,
    String? name,
    String? hsnCode,
    double? cgst,
    double? sgst,
    double? igst,
    double? currentStock,
    double? minimumStock,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      hsnCode: hsnCode ?? this.hsnCode,
      cgst: cgst ?? this.cgst,
      sgst: sgst ?? this.sgst,
      igst: igst ?? this.igst,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'hsnCode': hsnCode,
      'cgst': cgst,
      'sgst': sgst,
      'igst': igst,
      'currentStock': currentStock,
      'minimumStock': minimumStock,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ProductModel(
      id: documentId,
      name: map['name'] ?? '',
      hsnCode: map['hsnCode'],
      cgst: (map['cgst'] ?? 0.0).toDouble(),
      sgst: (map['sgst'] ?? 0.0).toDouble(),
      igst: (map['igst'] ?? 0.0).toDouble(),
      currentStock: (map['currentStock'] ?? 0.0).toDouble(),
      minimumStock: (map['minimumStock'] ?? 0.0).toDouble(),
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: map['isDeleted'] ?? false,
      deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory ProductModel.fromJson(Map<String, dynamic> source, String documentId) => 
      ProductModel.fromMap(source, documentId);

  @override
  List<Object?> get props => [
        id,
        name,
        hsnCode,
        cgst,
        sgst,
        igst,
        currentStock,
        minimumStock,
        isActive,
        createdAt,
        updatedAt,
        isDeleted,
        deletedAt,
      ];
}

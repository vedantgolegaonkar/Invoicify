import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum TransactionType {
  stockIn,
  stockOut,
}

extension TransactionTypeExtension on TransactionType {
  String get name {
    switch (this) {
      case TransactionType.stockIn:
        return 'StockIn';
      case TransactionType.stockOut:
        return 'StockOut';
    }
  }

  static TransactionType fromString(String type) {
    switch (type) {
      case 'StockIn':
        return TransactionType.stockIn;
      case 'StockOut':
        return TransactionType.stockOut;
      default:
        return TransactionType.stockIn;
    }
  }
}

class InventoryTransactionModel extends Equatable {
  final String id;
  final String productId;
  final TransactionType type;
  final double quantity;
  final double previousStock;
  final double newStock;
  final String? remarks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  const InventoryTransactionModel({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    this.remarks,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  InventoryTransactionModel copyWith({
    String? id,
    String? productId,
    TransactionType? type,
    double? quantity,
    double? previousStock,
    double? newStock,
    String? remarks,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return InventoryTransactionModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      previousStock: previousStock ?? this.previousStock,
      newStock: newStock ?? this.newStock,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'type': type.name,
      'quantity': quantity,
      'previousStock': previousStock,
      'newStock': newStock,
      'remarks': remarks,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  factory InventoryTransactionModel.fromMap(Map<String, dynamic> map, String documentId) {
    return InventoryTransactionModel(
      id: documentId,
      productId: map['productId'] ?? '',
      type: TransactionTypeExtension.fromString(map['type'] ?? 'StockIn'),
      quantity: (map['quantity'] ?? 0.0).toDouble(),
      previousStock: (map['previousStock'] ?? 0.0).toDouble(),
      newStock: (map['newStock'] ?? 0.0).toDouble(),
      remarks: map['remarks'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: map['isDeleted'] ?? false,
      deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory InventoryTransactionModel.fromJson(Map<String, dynamic> source, String documentId) => 
      InventoryTransactionModel.fromMap(source, documentId);

  @override
  List<Object?> get props => [
        id,
        productId,
        type,
        quantity,
        previousStock,
        newStock,
        remarks,
        createdAt,
        updatedAt,
        isDeleted,
        deletedAt,
      ];
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum OrderStatus {
  draft,
  confirmed,
  delivered,
  cancelled
}

extension OrderStatusExtension on OrderStatus {
  String get name {
    switch (this) {
      case OrderStatus.draft:
        return 'Draft';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  static OrderStatus fromString(String status) {
    switch (status) {
      case 'Draft':
        return OrderStatus.draft;
      case 'Confirmed':
        return OrderStatus.confirmed;
      case 'Delivered':
        return OrderStatus.delivered;
      case 'Cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.draft;
    }
  }
}

class OrderItem extends Equatable {
  final String productId;
  final String productName;
  final String? hsnCode;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final double gstAmount;
  final double total;

  const OrderItem({
    required this.productId,
    required this.productName,
    this.hsnCode,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.gstAmount,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'hsnCode': hsnCode,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'subtotal': subtotal,
      'gstAmount': gstAmount,
      'total': total,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      hsnCode: map['hsnCode'],
      quantity: (map['quantity'] ?? 0.0).toDouble(),
      unitPrice: (map['unitPrice'] ?? 0.0).toDouble(),
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
      gstAmount: (map['gstAmount'] ?? 0.0).toDouble(),
      total: (map['total'] ?? 0.0).toDouble(),
    );
  }

  @override
  List<Object?> get props => [
        productId,
        productName,
        hsnCode,
        quantity,
        unitPrice,
        subtotal,
        gstAmount,
        total,
      ];
}

class OrderModel extends Equatable {
  final String id;
  final String customerId;
  final String orderNumber;
  final DateTime orderDate;
  final OrderStatus status;
  final List<OrderItem> items;
  final double subtotal;
  final double gst;
  final double total;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  const OrderModel({
    required this.id,
    required this.customerId,
    required this.orderNumber,
    required this.orderDate,
    required this.status,
    required this.items,
    required this.subtotal,
    required this.gst,
    required this.total,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  OrderModel copyWith({
    String? id,
    String? customerId,
    String? orderNumber,
    DateTime? orderDate,
    OrderStatus? status,
    List<OrderItem>? items,
    double? subtotal,
    double? gst,
    double? total,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      orderNumber: orderNumber ?? this.orderNumber,
      orderDate: orderDate ?? this.orderDate,
      status: status ?? this.status,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      gst: gst ?? this.gst,
      total: total ?? this.total,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'orderNumber': orderNumber,
      'orderDate': Timestamp.fromDate(orderDate),
      'status': status.name,
      'items': items.map((x) => x.toMap()).toList(),
      'subtotal': subtotal,
      'gst': gst,
      'total': total,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, String documentId) {
    return OrderModel(
      id: documentId,
      customerId: map['customerId'] ?? '',
      orderNumber: map['orderNumber'] ?? '',
      orderDate: (map['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: OrderStatusExtension.fromString(map['status'] ?? 'Draft'),
      items: List<OrderItem>.from(
        (map['items'] as List? ?? []).map((x) => OrderItem.fromMap(x)),
      ),
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
      gst: (map['gst'] ?? 0.0).toDouble(),
      total: (map['total'] ?? 0.0).toDouble(),
      notes: map['notes'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: map['isDeleted'] ?? false,
      deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory OrderModel.fromJson(Map<String, dynamic> source, String documentId) => 
      OrderModel.fromMap(source, documentId);

  @override
  List<Object?> get props => [
        id,
        customerId,
        orderNumber,
        orderDate,
        status,
        items,
        subtotal,
        gst,
        total,
        notes,
        createdAt,
        updatedAt,
        isDeleted,
        deletedAt,
      ];
}

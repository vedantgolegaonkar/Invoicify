import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
// Removed unused import

enum InvoiceStatus {
  paid,
  partiallyPaid,
  unpaid
}

extension InvoiceStatusExtension on InvoiceStatus {
  String get name {
    switch (this) {
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.partiallyPaid:
        return 'PartiallyPaid';
      case InvoiceStatus.unpaid:
        return 'Unpaid';
    }
  }

  static InvoiceStatus fromString(String status) {
    switch (status) {
      case 'Paid':
        return InvoiceStatus.paid;
      case 'PartiallyPaid':
        return InvoiceStatus.partiallyPaid;
      case 'Unpaid':
        return InvoiceStatus.unpaid;
      default:
        return InvoiceStatus.unpaid;
    }
  }
}

class InvoiceItem extends Equatable {
  final String productId;
  final String productName;
  final String? hsnCode;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final double gstAmount;
  final double total;

  const InvoiceItem({
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

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
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

class InvoiceModel extends Equatable {
  final String id;
  final String customerId;
  final String orderId;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final List<InvoiceItem> items;
  final double subtotal;
  final double gst;
  final double total;
  final InvoiceStatus status;
  final bool isDelivered;
  final DateTime? deliveryDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  const InvoiceModel({
    required this.id,
    required this.customerId,
    required this.orderId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.items,
    required this.subtotal,
    required this.gst,
    required this.total,
    required this.status,
    required this.isDelivered,
    this.deliveryDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  InvoiceModel copyWith({
    String? id,
    String? customerId,
    String? orderId,
    String? invoiceNumber,
    DateTime? invoiceDate,
    List<InvoiceItem>? items,
    double? subtotal,
    double? gst,
    double? total,
    InvoiceStatus? status,
    bool? isDelivered,
    DateTime? deliveryDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      orderId: orderId ?? this.orderId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      gst: gst ?? this.gst,
      total: total ?? this.total,
      status: status ?? this.status,
      isDelivered: isDelivered ?? this.isDelivered,
      deliveryDate: deliveryDate ?? this.deliveryDate,
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
      'orderId': orderId,
      'invoiceNumber': invoiceNumber,
      'invoiceDate': Timestamp.fromDate(invoiceDate),
      'items': items.map((x) => x.toMap()).toList(),
      'subtotal': subtotal,
      'gst': gst,
      'total': total,
      'status': status.name,
      'isDelivered': isDelivered,
      'deliveryDate': deliveryDate != null ? Timestamp.fromDate(deliveryDate!) : null,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> map, String documentId) {
    return InvoiceModel(
      id: documentId,
      customerId: map['customerId'] ?? '',
      orderId: map['orderId'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      invoiceDate: (map['invoiceDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      items: List<InvoiceItem>.from(
        (map['items'] as List? ?? []).map((x) => InvoiceItem.fromMap(x)),
      ),
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
      gst: (map['gst'] ?? 0.0).toDouble(),
      total: (map['total'] ?? 0.0).toDouble(),
      status: InvoiceStatusExtension.fromString(map['status'] ?? 'Unpaid'),
      isDelivered: map['isDelivered'] ?? false,
      deliveryDate: (map['deliveryDate'] as Timestamp?)?.toDate(),
      notes: map['notes'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: map['isDeleted'] ?? false,
      deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory InvoiceModel.fromJson(Map<String, dynamic> source, String documentId) => 
      InvoiceModel.fromMap(source, documentId);

  @override
  List<Object?> get props => [
        id,
        customerId,
        orderId,
        invoiceNumber,
        invoiceDate,
        items,
        subtotal,
        gst,
        total,
        status,
        isDelivered,
        deliveryDate,
        notes,
        createdAt,
        updatedAt,
        isDeleted,
        deletedAt,
      ];
}

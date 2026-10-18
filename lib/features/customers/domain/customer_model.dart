import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class CustomerModel extends Equatable {
  final String id;
  final String name;
  final String? businessName;
  final String mobile;
  final String? whatsappNumber;
  final String? email;
  final String address;
  final double currentOutstanding;
  final Map<String, double>? productPrices;
  final String? notes;
  final String? gstNumber;
  final String? stateName;
  final String? stateCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  const CustomerModel({
    required this.id,
    required this.name,
    this.businessName,
    required this.mobile,
    this.whatsappNumber,
    this.email,
    required this.address,
    required this.currentOutstanding,
    this.productPrices,
    this.notes,
    this.gstNumber,
    this.stateName,
    this.stateCode,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  CustomerModel copyWith({
    String? id,
    String? name,
    String? businessName,
    String? mobile,
    String? whatsappNumber,
    String? email,
    String? address,
    double? currentOutstanding,
    Map<String, double>? productPrices,
    String? notes,
    String? gstNumber,
    String? stateName,
    String? stateCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      businessName: businessName ?? this.businessName,
      mobile: mobile ?? this.mobile,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      currentOutstanding: currentOutstanding ?? this.currentOutstanding,
      productPrices: productPrices ?? this.productPrices,
      notes: notes ?? this.notes,
      gstNumber: gstNumber ?? this.gstNumber,
      stateName: stateName ?? this.stateName,
      stateCode: stateCode ?? this.stateCode,
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
      'businessName': businessName,
      'mobile': mobile,
      'whatsappNumber': whatsappNumber,
      'email': email,
      'address': address,
      'currentOutstanding': currentOutstanding,
      'productPrices': productPrices,
      'notes': notes,
      'gstNumber': gstNumber,
      'stateName': stateName,
      'stateCode': stateCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CustomerModel(
      id: documentId,
      name: map['name'] ?? '',
      businessName: map['businessName'],
      mobile: map['mobile'] ?? '',
      whatsappNumber: map['whatsappNumber'],
      email: map['email'],
      address: map['address'] ?? '',
      currentOutstanding: (map['currentOutstanding'] ?? 0.0).toDouble(),
      productPrices: map['productPrices'] != null 
          ? Map<String, double>.from((map['productPrices'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())))
          : null,
      notes: map['notes'],
      gstNumber: map['gstNumber'],
      stateName: map['stateName'],
      stateCode: map['stateCode'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: map['isDeleted'] ?? false,
      deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory CustomerModel.fromJson(Map<String, dynamic> source, String documentId) => 
      CustomerModel.fromMap(source, documentId);

  @override
  List<Object?> get props => [
        id,
        name,
        businessName,
        mobile,
        whatsappNumber,
        email,
        address,
        currentOutstanding,
        productPrices,
        notes,
        gstNumber,
        stateName,
        stateCode,
        createdAt,
        updatedAt,
        isDeleted,
        deletedAt,
      ];
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class BusinessModel extends Equatable {
  final String id;
  final String businessName;
  final String? gstNumber;
  final String? fssaiNumber;
  final String address;
  final String phone;
  final String? logoUrl;
  final String? signatureUrl;
  final String invoicePrefix;
  final int invoiceStartNumber;
  // Bank & payment details
  final String? bankName;
  final String? bankAccount;
  final String? bankIfsc;
  final String? upiId;
  // Invoice footer
  final String? termsAndConditions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  const BusinessModel({
    required this.id,
    required this.businessName,
    this.gstNumber,
    this.fssaiNumber,
    required this.address,
    required this.phone,
    this.logoUrl,
    this.signatureUrl,
    required this.invoicePrefix,
    required this.invoiceStartNumber,
    this.bankName,
    this.bankAccount,
    this.bankIfsc,
    this.upiId,
    this.termsAndConditions,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  BusinessModel copyWith({
    String? id,
    String? businessName,
    String? gstNumber,
    String? fssaiNumber,
    String? address,
    String? phone,
    String? logoUrl,
    String? signatureUrl,
    String? invoicePrefix,
    int? invoiceStartNumber,
    String? bankName,
    String? bankAccount,
    String? bankIfsc,
    String? upiId,
    String? termsAndConditions,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return BusinessModel(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      gstNumber: gstNumber ?? this.gstNumber,
      fssaiNumber: fssaiNumber ?? this.fssaiNumber,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      logoUrl: logoUrl ?? this.logoUrl,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      invoiceStartNumber: invoiceStartNumber ?? this.invoiceStartNumber,
      bankName: bankName ?? this.bankName,
      bankAccount: bankAccount ?? this.bankAccount,
      bankIfsc: bankIfsc ?? this.bankIfsc,
      upiId: upiId ?? this.upiId,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessName': businessName,
      'gstNumber': gstNumber,
      'fssaiNumber': fssaiNumber,
      'address': address,
      'phone': phone,
      'logoUrl': logoUrl,
      'signatureUrl': signatureUrl,
      'invoicePrefix': invoicePrefix,
      'invoiceStartNumber': invoiceStartNumber,
      'bankName': bankName,
      'bankAccount': bankAccount,
      'bankIfsc': bankIfsc,
      'upiId': upiId,
      'termsAndConditions': termsAndConditions,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  factory BusinessModel.fromMap(Map<String, dynamic> map, String documentId) {
    return BusinessModel(
      id: documentId,
      businessName: map['businessName'] ?? '',
      gstNumber: map['gstNumber'],
      fssaiNumber: map['fssaiNumber'],
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      logoUrl: map['logoUrl'],
      signatureUrl: map['signatureUrl'],
      invoicePrefix: map['invoicePrefix'] ?? '',
      invoiceStartNumber: map['invoiceStartNumber']?.toInt() ?? 1,
      bankName: map['bankName'],
      bankAccount: map['bankAccount'],
      bankIfsc: map['bankIfsc'],
      upiId: map['upiId'],
      termsAndConditions: map['termsAndConditions'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: map['isDeleted'] ?? false,
      deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory BusinessModel.fromJson(Map<String, dynamic> source, String documentId) => 
      BusinessModel.fromMap(source, documentId);

  @override
  List<Object?> get props => [
        id,
        businessName,
        gstNumber,
        fssaiNumber,
        address,
        phone,
        logoUrl,
        signatureUrl,
        invoicePrefix,
        invoiceStartNumber,
        bankName,
        bankAccount,
        bankIfsc,
        upiId,
        termsAndConditions,
        createdAt,
        updatedAt,
        isDeleted,
        deletedAt,
      ];
}

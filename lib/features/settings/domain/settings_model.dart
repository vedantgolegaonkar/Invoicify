import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class SettingsModel extends Equatable {
  final String id;
  final bool pinEnabled;
  final String? pin;
  final String? digitalSignature;
  final String invoicePrefix;
  final int invoiceNextNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  const SettingsModel({
    required this.id,
    required this.pinEnabled,
    this.pin,
    this.digitalSignature,
    required this.invoicePrefix,
    required this.invoiceNextNumber,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  SettingsModel copyWith({
    String? id,
    bool? pinEnabled,
    String? pin,
    String? digitalSignature,
    String? invoicePrefix,
    int? invoiceNextNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return SettingsModel(
      id: id ?? this.id,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      pin: pin ?? this.pin,
      digitalSignature: digitalSignature ?? this.digitalSignature,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      invoiceNextNumber: invoiceNextNumber ?? this.invoiceNextNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pinEnabled': pinEnabled,
      'pin': pin,
      'digitalSignature': digitalSignature,
      'invoicePrefix': invoicePrefix,
      'invoiceNextNumber': invoiceNextNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map, String documentId) {
    return SettingsModel(
      id: documentId,
      pinEnabled: map['pinEnabled'] ?? false,
      pin: map['pin'],
      digitalSignature: map['digitalSignature'],
      invoicePrefix: map['invoicePrefix'] ?? 'INV-',
      invoiceNextNumber: map['invoiceNextNumber']?.toInt() ?? 1,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: map['isDeleted'] ?? false,
      deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory SettingsModel.fromJson(Map<String, dynamic> source, String documentId) => 
      SettingsModel.fromMap(source, documentId);

  @override
  List<Object?> get props => [
        id,
        pinEnabled,
        pin,
        digitalSignature,
        invoicePrefix,
        invoiceNextNumber,
        createdAt,
        updatedAt,
        isDeleted,
        deletedAt,
      ];
}

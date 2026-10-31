import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String mobileNumber;
  final String pinHash;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.mobileNumber,
    required this.pinHash,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      mobileNumber: map['mobileNumber'] ?? '',
      pinHash: map['pinHash'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mobileNumber': mobileNumber,
      'pinHash': pinHash,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

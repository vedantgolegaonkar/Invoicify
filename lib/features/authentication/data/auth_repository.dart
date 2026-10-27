import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../services/firestore_service.dart';
import '../domain/user_model.dart';
import '../../../core/providers/firebase_providers.dart';

class AuthRepository {
  final FirestoreService _firestoreService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final String _usersCollection = 'users';

  AuthRepository(this._firestoreService);

  String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<UserModel?> checkMobileNumberExists(String mobileNumber) async {
    final docs = await _firestoreService.getCollection<UserModel>(
      path: _usersCollection,
      builder: UserModel.fromMap,
      queryBuilder: (query) => query.where('mobileNumber', isEqualTo: mobileNumber).limit(1),
    );
    if (docs.isNotEmpty) {
      return docs.first;
    }
    return null;
  }

  Future<UserModel> registerUser(String mobileNumber, String pin) async {
    final existingUser = await checkMobileNumberExists(mobileNumber);
    if (existingUser != null) {
      throw Exception('Mobile number already exists.');
    }

    final String pinHash = hashPin(pin);
    final String newUserId = _firestoreService.instance.collection(_usersCollection).doc().id;

    final newUser = UserModel(
      id: newUserId,
      mobileNumber: mobileNumber,
      pinHash: pinHash,
      createdAt: DateTime.now(),
    );

    await _firestoreService.setDocument(_usersCollection, newUserId, newUser.toMap());
    
    // Save to secure storage for offline checking later
    await _secureStorage.write(key: 'local_pin_hash_$newUserId', value: pinHash);

    return newUser;
  }

  Future<bool> verifyPin(UserModel user, String pin) async {
    final String hashedPin = hashPin(pin);
    if (user.pinHash == hashedPin) {
      await _secureStorage.write(key: 'local_pin_hash_${user.id}', value: hashedPin);
      return true;
    }
    return false;
  }

  Future<bool> verifyPinLocally(String userId, String pin) async {
    final String? localHash = await _secureStorage.read(key: 'local_pin_hash_$userId');
    if (localHash == null) {
      // If no local hash, try to fetch from server
      final user = await getUser(userId);
      if (user != null) {
        return verifyPin(user, pin);
      }
      return false;
    }
    final String inputHash = hashPin(pin);
    return localHash == inputHash;
  }

  Future<UserModel?> getUser(String userId) async {
    return _firestoreService.getDocument<UserModel>(
      path: _usersCollection,
      id: userId,
      builder: UserModel.fromMap,
    );
  }

  Future<void> saveCurrentUserId(String userId) async {
    await _secureStorage.write(key: 'current_user_id', value: userId);
  }

  Future<String?> getCurrentUserId() async {
    return await _secureStorage.read(key: 'current_user_id');
  }

  Future<void> clearCurrentUser() async {
    await _secureStorage.delete(key: 'current_user_id');
  }

  /// Permanently deletes the user's account and all associated Firestore data and local storage.
  Future<void> deleteUserAccountAndData(String userId) async {
    // List of all subcollections under users/{userId}
    final subcollections = [
      'customers',
      'products',
      'orders',
      'invoices',
      'payments',
      'inventory_transactions',
      'settings',
      'business',
      'notifications',
      'audit_logs',
    ];

    // Delete documents in each subcollection in batches
    for (final col in subcollections) {
      try {
        final querySnapshot = await _firestoreService.instance
            .collection('users/$userId/$col')
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          final batch = _firestoreService.instance.batch();
          for (final doc in querySnapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      } catch (e) {
        // Continue cleaning other collections even if one fails
      }
    }

    // Delete the root user profile document
    try {
      await _firestoreService.instance.collection(_usersCollection).doc(userId).delete();
    } catch (_) {}

    // Clear local stored credentials
    await _secureStorage.delete(key: 'local_pin_hash_$userId');
    await _secureStorage.delete(key: 'current_user_id');
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return AuthRepository(firestoreService);
});

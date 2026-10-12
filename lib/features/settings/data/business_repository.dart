import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repositories/base_repository.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../domain/business_model.dart';
import '../../../../services/firestore_service.dart';
import '../../authentication/presentation/providers/auth_provider.dart';

class BusinessRepository extends BaseRepository<BusinessModel> {
  BusinessRepository(FirestoreService firestoreService, String userId)
      : super(firestoreService, 'users/$userId/business');

  @override
  BusinessModel fromMap(Map<String, dynamic> map, String id) {
    return BusinessModel.fromMap(map, id);
  }

  @override
  Map<String, dynamic> toMap(BusinessModel item) {
    return item.toMap();
  }
}

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final userId = ref.watch(authUserIdProvider) ?? 'unauthenticated';
  return BusinessRepository(firestoreService, userId);
});

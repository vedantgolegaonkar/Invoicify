import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repositories/base_repository.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../domain/settings_model.dart';
import '../../../../services/firestore_service.dart';
import '../../authentication/presentation/providers/auth_provider.dart';

class SettingsRepository extends BaseRepository<SettingsModel> {
  SettingsRepository(FirestoreService firestoreService, String userId)
      : super(firestoreService, 'users/$userId/settings');

  @override
  SettingsModel fromMap(Map<String, dynamic> map, String id) {
    return SettingsModel.fromMap(map, id);
  }

  @override
  Map<String, dynamic> toMap(SettingsModel item) {
    return item.toMap();
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final userId = ref.watch(authUserIdProvider) ?? 'unauthenticated';
  return SettingsRepository(firestoreService, userId);
});

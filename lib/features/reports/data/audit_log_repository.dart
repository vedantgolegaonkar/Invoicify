import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repositories/base_repository.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../domain/audit_log_model.dart';
import '../../../../services/firestore_service.dart';
import '../../authentication/presentation/providers/auth_provider.dart';

class AuditLogRepository extends BaseRepository<AuditLogModel> {
  AuditLogRepository(FirestoreService firestoreService, String userId)
      : super(firestoreService, 'users/$userId/audit_logs');

  @override
  AuditLogModel fromMap(Map<String, dynamic> map, String id) {
    return AuditLogModel.fromMap(map, id);
  }

  @override
  Map<String, dynamic> toMap(AuditLogModel item) {
    return item.toMap();
  }
}

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final userId = ref.watch(authUserIdProvider) ?? 'unauthenticated';
  return AuditLogRepository(firestoreService, userId);
});

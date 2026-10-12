import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repositories/base_repository.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../domain/invoice_model.dart';
import '../../../../services/firestore_service.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../authentication/presentation/providers/auth_provider.dart';

class InvoiceRepository extends BaseRepository<InvoiceModel> {
  InvoiceRepository(FirestoreService firestoreService, String userId, {Future<void> Function(String, String)? onLogNotification})
      : super(firestoreService, 'users/$userId/invoices', onLogNotification: onLogNotification);

  @override
  InvoiceModel fromMap(Map<String, dynamic> map, String id) {
    return InvoiceModel.fromMap(map, id);
  }

  @override
  Map<String, dynamic> toMap(InvoiceModel item) {
    return item.toMap();
  }
}

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final logger = ref.watch(notificationLoggerProvider);
  final userId = ref.watch(authUserIdProvider) ?? 'unauthenticated';
  return InvoiceRepository(firestoreService, userId, onLogNotification: logger);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../products/providers/product_providers.dart';
import '../../../services/notification_service.dart';

import '../../authentication/presentation/providers/auth_provider.dart';

// We just need this provider to stay alive and listen to the stream,
// so we'll make it a Provider that watches the productsStreamProvider when authenticated.
final lowStockNotifierProvider = Provider<void>((ref) {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null || userId == 'unauthenticated') {
    return;
  }
  
  final productsAsync = ref.watch(productsStreamProvider);
  
  // Maintain state of which products we've already alerted about
  // so we don't spam notifications every time the stream updates.
  // We use ref.keepAlive() to ensure this provider and its state aren't disposed.
  ref.keepAlive();
  
  // Read the state from a separate provider to persist across rebuilds of *this* provider
  final alertedIds = ref.read(_alertedProductIdsProvider);

  productsAsync.whenData((products) {
    for (final product in products) {
      if (product.currentStock <= product.minimumStock) {
        // Only alert if we haven't alerted for this specific product already
        if (!alertedIds.contains(product.id)) {
          NotificationService().showLowStockNotification(
            productId: product.id,
            productName: product.name,
            currentStock: product.currentStock,
          );
          alertedIds.add(product.id);
        }
      } else {
        // If stock is above minimum, remove from alerted list so it can trigger again
        // if it falls back down in the future.
        alertedIds.remove(product.id);
      }
    }
  });
});

final _alertedProductIdsProvider = Provider<Set<String>>((ref) {
  return <String>{};
});

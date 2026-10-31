import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/settings_repository.dart';
import '../domain/settings_model.dart';

import '../../authentication/presentation/providers/auth_provider.dart';

final settingsStreamProvider = StreamProvider<SettingsModel?>((ref) {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null || userId == 'unauthenticated') {
    return const Stream.empty();
  }
  final repository = ref.watch(settingsRepositoryProvider);
  
  return repository.streamAll().map((settingsList) {
    if (settingsList.isEmpty) return null;
    try {
      return settingsList.firstWhere((s) => s.id == 'default');
    } catch (_) {
      return settingsList.first;
    }
  });
});

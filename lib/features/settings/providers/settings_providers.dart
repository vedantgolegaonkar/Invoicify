import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/settings_repository.dart';
import '../domain/settings_model.dart';

final settingsStreamProvider = StreamProvider<SettingsModel?>((ref) {
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

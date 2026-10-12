import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashlyticsService {
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  Future<void> recordError(dynamic exception, StackTrace? stack, {dynamic reason}) async {
    if (!kIsWeb) {
      await _crashlytics.recordError(exception, stack, reason: reason);
    } else {
      debugPrint('Crashlytics error: $exception\n$stack');
    }
  }

  Future<void> log(String message) async {
    if (!kIsWeb) {
      await _crashlytics.log(message);
    } else {
      debugPrint('Crashlytics log: $message');
    }
  }

  Future<void> setUserId(String identifier) async {
    if (!kIsWeb) {
      await _crashlytics.setUserIdentifier(identifier);
    }
  }
}

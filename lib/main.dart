import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';
import 'services/snackbar_service.dart';
import 'services/notification_service.dart';
import 'features/inventory/providers/low_stock_notifier.dart';

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

void main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e, stack) {
      debugPrint('Firebase.initializeApp failed: $e\n$stack');
    }
    
    try {
      await NotificationService().init();
    } catch (e, stack) {
      debugPrint('NotificationService.init failed: $e\n$stack');
    }

    runApp(
      const ProviderScope(
        child: MyApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught top-level error: $error\n$stack');
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {}
  });
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    // Initialize the low stock notifier so it listens in the background
    ref.watch(lowStockNotifierProvider);

    return MaterialApp.router(
      title: 'Invoicify',
      theme: AppTheme.lightTheme,
      scaffoldMessengerKey: SnackbarService.scaffoldMessengerKey,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

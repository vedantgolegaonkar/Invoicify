import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/auth_repository.dart';
import '../../../../services/notification_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _initSplash();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initSplash() async {
    // Play animation immediately
    _animationController.forward();
    
    // Request permissions non-blocking so it never hangs the splash screen
    NotificationService().requestPermissions().catchError((_) => false);
    
    // Check auth in background
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    
    try {
      final repository = ref.read(authRepositoryProvider);
      final userId = await repository.getCurrentUserId().timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      
      if (userId != null) {
        try {
          final user = await repository.getUser(userId).timeout(
            const Duration(seconds: 4),
            onTimeout: () => null,
          );
          if (mounted) {
            if (user != null) {
              context.go('/pin');
            } else {
              await repository.clearCurrentUser();
              if (mounted) context.go('/login');
            }
          }
        } catch (e) {
          // Fallback to pin screen if offline or network error
          if (mounted) {
            context.go('/pin');
          }
        }
      } else {
        if (mounted) {
          context.go('/login');
        }
      }
    } catch (_) {
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo.png',
                  width: 140,
                  height: 140,
                ),
                const SizedBox(height: 32),
                Text(
                  'Invoicify',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Smart Billing Solutions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.black54,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 64),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                    strokeWidth: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


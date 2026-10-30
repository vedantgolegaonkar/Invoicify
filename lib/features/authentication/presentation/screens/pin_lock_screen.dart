import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  String _pin = '';
  bool _isLoading = false;
  String? _errorMessage;
  int _failedAttempts = 0;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _startLockout(int seconds) {
    setState(() {
      _lockoutSeconds = seconds;
      _errorMessage = 'Too many failed attempts. Try again in $_lockoutSeconds seconds.';
      _pin = '';
    });
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_lockoutSeconds > 1) {
          _lockoutSeconds--;
          _errorMessage = 'Too many failed attempts. Try again in $_lockoutSeconds seconds.';
        } else {
          _lockoutSeconds = 0;
          _errorMessage = null;
          timer.cancel();
        }
      });
    });
  }

  void _onKeyPress(String key) {
    if (_lockoutSeconds > 0) return;
    if (_pin.length < 4) {
      setState(() {
        _pin += key;
        _errorMessage = null;
      });
      if (_pin.length == 4) {
        _verifyPin();
      }
    }
  }

  Future<void> _verifyPin() async {
    if (_lockoutSeconds > 0) return;
    setState(() {
      _isLoading = true;
    });
    
    final isValid = await ref.read(authNotifierProvider.notifier).verifyLocalPin(_pin);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (isValid) {
        _failedAttempts = 0;
        context.go('/dashboard');
      } else {
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          _startLockout(30);
        } else {
          final remaining = 5 - _failedAttempts;
          setState(() {
            _errorMessage = 'Invalid PIN. $remaining attempt${remaining == 1 ? '' : 's'} remaining.';
            _pin = '';
          });
        }
      }
    }
  }

  void _onDelete() {
    if (_lockoutSeconds > 0) return;
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      const Icon(Icons.lock_outline, size: 64),
                      const SizedBox(height: 24),
                      Text(
                        'Enter PIN',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index < _pin.length
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey.shade300,
                            ),
                          );
                        }),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      if (_isLoading) ...[
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(),
                      ],
                      const SizedBox(height: 32),
                      _buildNumpad(),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          ref.read(authNotifierProvider.notifier).logout();
                          context.go('/login');
                        },
                        child: const Text('Logout'),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKey('1'),
              _buildKey('2'),
              _buildKey('3'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKey('4'),
              _buildKey('5'),
              _buildKey('6'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKey('7'),
              _buildKey('8'),
              _buildKey('9'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 72),
              _buildKey('0'),
              _buildDeleteKey(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String value) {
    return InkWell(
      onTap: () => _onKeyPress(value),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildDeleteKey() {
    return InkWell(
      onTap: _onDelete,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        child: const Icon(Icons.backspace_outlined, size: 28),
      ),
    );
  }
}

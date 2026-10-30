import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _mobileController = TextEditingController();
  String _pin = '';
  String _tempPin = '';
  bool _showPinScreen = false;
  bool _isNewUser = false;
  bool _isConfirmingPin = false;
  bool _isLoading = false;
  String? _errorMessage;
  int _failedAttempts = 0;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _mobileController.dispose();
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
        if (_isNewUser && !_isConfirmingPin) {
          // Move to confirm PIN state
          setState(() {
            _tempPin = _pin;
            _pin = '';
            _isConfirmingPin = true;
          });
        } else if (_isNewUser && _isConfirmingPin) {
          // Check if match
          if (_pin == _tempPin) {
            _submit();
          } else {
            setState(() {
              _errorMessage = 'PINs do not match. Try again.';
              _pin = '';
              _tempPin = '';
              _isConfirmingPin = false;
            });
          }
        } else {
          // Existing user, just submit
          _submit();
        }
      }
    }
  }

  void _onDelete() {
    if (_lockoutSeconds > 0) return;
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_lockoutSeconds > 0) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await ref.read(authNotifierProvider.notifier).loginOrRegister(
        _mobileController.text.trim(),
        _pin,
      );
      
      if (success && mounted) {
        _failedAttempts = 0;
        context.go('/dashboard');
      }
    } catch (e) {
      if (!_isNewUser) {
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          _startLockout(30);
          return;
        }
      }
      final remaining = 5 - _failedAttempts;
      final extraWarning = (!_isNewUser && remaining > 0 && remaining < 5)
          ? ' ($remaining attempt${remaining == 1 ? '' : 's'} remaining)'
          : '';
      setState(() {
        _errorMessage = '${e.toString().replaceAll('Exception: ', '')}$extraWarning';
        _pin = '';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                  child: _showPinScreen ? _buildPinScreen() : _buildMobileScreen(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset(
            'assets/logo.png',
            width: 100,
            height: 100,
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your mobile number to continue',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Mobile Number',
              hintText: '9876543210',
              prefixText: '+91 ',
              counterText: '',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : () async {
              final mobile = _mobileController.text.trim();
              if (RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
                setState(() => _isLoading = true);
                try {
                  final exists = await ref.read(authNotifierProvider.notifier).checkMobileExists(mobile);
                  if (mounted) {
                    setState(() {
                      _isNewUser = !exists;
                      _showPinScreen = true;
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid 10-digit mobile number starting with 6-9')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildPinScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline, size: 64),
        const SizedBox(height: 24),
        Text(
          _isNewUser 
              ? (_isConfirmingPin ? 'Confirm PIN' : 'Set PIN') 
              : 'Enter PIN',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'For ${_mobileController.text}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
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
            setState(() {
              if (_isConfirmingPin) {
                _isConfirmingPin = false;
                _pin = '';
                _tempPin = '';
                _errorMessage = null;
              } else {
                _showPinScreen = false;
                _pin = '';
                _tempPin = '';
                _errorMessage = null;
              }
            });
          },
          child: Text(_isConfirmingPin ? 'Back to Set PIN' : 'Back to Mobile Number'),
        ),
        const SizedBox(height: 32),
      ],
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
      onTap: _isLoading ? null : () => _onKeyPress(value),
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
      onTap: _isLoading ? null : _onDelete,
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

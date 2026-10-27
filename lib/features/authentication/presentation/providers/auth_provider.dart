import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/user_model.dart';

final authUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authNotifierProvider).value?.id;
});

class AuthNotifier extends AsyncNotifier<UserModel?> {
  late AuthRepository _authRepository;

  @override
  Future<UserModel?> build() async {
    _authRepository = ref.watch(authRepositoryProvider);
    return _initialize();
  }

  Future<UserModel?> _initialize() async {
    final userId = await _authRepository.getCurrentUserId();
    if (userId != null) {
      // Fetch user object asynchronously but consider logged in locally
      return await _authRepository.getUser(userId);
    }
    return null;
  }

  Future<bool> checkMobileExists(String mobileNumber) async {
    final user = await _authRepository.checkMobileNumberExists(mobileNumber);
    return user != null;
  }

  Future<bool> loginOrRegister(String mobileNumber, String pin) async {
    state = const AsyncValue.loading();
    try {
      UserModel? user = await _authRepository.checkMobileNumberExists(mobileNumber);
      
      if (user != null) {
        // Login
        final isValid = await _authRepository.verifyPin(user, pin);
        if (!isValid) {
          state = const AsyncValue.data(null);
          throw Exception('Invalid PIN');
        }
      } else {
        // Register
        user = await _authRepository.registerUser(mobileNumber, pin);
      }

      await _authRepository.saveCurrentUserId(user.id);
      state = AsyncValue.data(user);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<bool> verifyLocalPin(String pin) async {
    final userId = await _authRepository.getCurrentUserId();
    if (userId == null) return false;
    
    try {
      final isValid = await _authRepository.verifyPinLocally(userId, pin);
      if (isValid) {
        try {
          final user = await _authRepository.getUser(userId);
          state = AsyncValue.data(user ?? UserModel(id: userId, mobileNumber: '', pinHash: '', createdAt: DateTime.now()));
        } catch (_) {
          state = AsyncValue.data(UserModel(id: userId, mobileNumber: '', pinHash: '', createdAt: DateTime.now()));
        }
      }
      return isValid;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.clearCurrentUser();
    state = const AsyncValue.data(null);
  }

  Future<void> deleteAccount() async {
    final user = state.value;
    final userId = user?.id ?? await _authRepository.getCurrentUserId();
    if (userId != null) {
      await _authRepository.deleteUserAccountAndData(userId);
    }
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, UserModel?>(AuthNotifier.new);

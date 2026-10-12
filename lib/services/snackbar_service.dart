import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class SnackbarService {
  SnackbarService._();

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void showSuccess(String message) {
    _showSnackbar(message, AppColors.success);
  }

  static void showError(String message) {
    _showSnackbar(message, AppColors.error);
  }

  static void showInfo(String message) {
    _showSnackbar(message, AppColors.info);
  }

  static void _showSnackbar(String message, Color backgroundColor) {
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

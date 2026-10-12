import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_strings.dart';

class AppSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final String hintText;

  const AppSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
    this.onClear,
    this.hintText = AppStrings.search,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(AppIcons.search),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(AppIcons.close),
                onPressed: () {
                  controller.clear();
                  if (onChanged != null) onChanged!('');
                  if (onClear != null) onClear!();
                },
              )
            : null,
      ),
    );
  }
}

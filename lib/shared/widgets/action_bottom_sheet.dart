import 'package:flutter/material.dart';

class ActionBottomSheet extends StatelessWidget {
  final List<BottomSheetAction> actions;

  const ActionBottomSheet({super.key, required this.actions});

  static Future<T?> show<T>(BuildContext context, List<BottomSheetAction> actions) {
    return showModalBottomSheet<T>(
      context: context,
      builder: (context) => ActionBottomSheet(actions: actions),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...actions.map((action) => ListTile(
                leading: Icon(action.icon, color: action.isDestructive ? Colors.red : null),
                title: Text(
                  action.title,
                  style: TextStyle(
                    color: action.isDestructive ? Colors.red : null,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  action.onTap();
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class BottomSheetAction {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  BottomSheetAction({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });
}

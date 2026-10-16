import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';

class MainLayout extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainLayout({
    super.key,
    required this.navigationShell,
  });

  void _onItemTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;

    final navItems = const [
      _NavItemData(
        label: 'Dashboard',
        selectedIcon: Icons.dashboard_rounded,
        unselectedIcon: Icons.dashboard_outlined,
      ),
      _NavItemData(
        label: 'Customers',
        selectedIcon: Icons.people_alt_rounded,
        unselectedIcon: Icons.people_outline_rounded,
      ),
      _NavItemData(
        label: 'Orders',
        selectedIcon: Icons.shopping_cart_rounded,
        unselectedIcon: Icons.shopping_cart_outlined,
      ),
      _NavItemData(
        label: 'Invoices',
        selectedIcon: Icons.receipt_long_rounded,
        unselectedIcon: Icons.receipt_long_outlined,
      ),
      _NavItemData(
        label: 'More',
        selectedIcon: Icons.menu_rounded,
        unselectedIcon: Icons.menu_rounded,
      ),
    ];

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(navItems.length, (index) {
                final item = navItems[index];
                final isSelected = currentIndex == index;

                return _buildModernNavItem(
                  context: context,
                  item: item,
                  isSelected: isSelected,
                  onTap: () => _onItemTapped(index),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernNavItem({
    required BuildContext context,
    required _NavItemData item,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      splashColor: AppColors.primary.withValues(alpha: 0.1),
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.fastOutSlowIn,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.selectedIcon : item.unselectedIcon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  item.label,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: isSelected
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 150),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemData {
  final String label;
  final IconData selectedIcon;
  final IconData unselectedIcon;

  const _NavItemData({
    required this.label,
    required this.selectedIcon,
    required this.unselectedIcon,
  });
}

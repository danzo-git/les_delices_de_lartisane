import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class AdminShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AdminShell({super.key, required this.navigationShell});

  static const List<_AdminNavItem> _navItems = [
    _AdminNavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
    ),
    _AdminNavItem(
      label: 'Commandes',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
    ),
    _AdminNavItem(
      label: 'Produits',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
    ),
    _AdminNavItem(
      label: 'Statistiques',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
    ),
    _AdminNavItem(
      label: 'Paramètres',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
    ),
  ];

  void _onItemTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vous déconnecter de l\'espace admin ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;
    final isLargeScreen = MediaQuery.of(context).size.width >= 768;

    if (isLargeScreen) {
      // NavigationRail pour tablettes/grands écrans
      return Scaffold(
        body: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: NavigationRail(
                selectedIndex: currentIndex,
                onDestinationSelected: _onItemTapped,
                backgroundColor: Colors.white,
                selectedIconTheme: const IconThemeData(color: AppColors.primaire),
                selectedLabelTextStyle: const TextStyle(
                  color: AppColors.primaire,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                unselectedIconTheme: const IconThemeData(color: AppColors.secondaire),
                unselectedLabelTextStyle: const TextStyle(
                  color: AppColors.secondaire,
                  fontSize: 12,
                ),
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaire,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bakery_dining, color: Colors.white, size: 24),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Admin',
                        style: TextStyle(
                          color: AppColors.primaire,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: IconButton(
                        onPressed: () => _logout(context, ref),
                        icon: const Icon(Icons.logout_rounded, color: AppColors.secondaire),
                        tooltip: 'Déconnexion',
                      ),
                    ),
                  ),
                ),
                destinations: _navItems
                    .map((item) => NavigationRailDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.activeIcon),
                          label: Text(item.label),
                        ))
                    .toList(),
              ),
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    // BottomNavigationBar pour téléphones
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: BottomNavigationBar(
                  currentIndex: currentIndex,
                  onTap: _onItemTapped,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: AppColors.primaire,
                  unselectedItemColor: AppColors.secondaire,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 10),
                  items: _navItems
                      .map((item) => BottomNavigationBarItem(
                            icon: Icon(item.icon, size: 22),
                            activeIcon: Icon(item.activeIcon, size: 22),
                            label: item.label,
                          ))
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  onPressed: () => _logout(context, ref),
                  icon: const Icon(Icons.logout_rounded, color: AppColors.secondaire, size: 22),
                  tooltip: 'Déconnexion',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _AdminNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

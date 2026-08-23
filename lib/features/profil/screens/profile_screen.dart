import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userProfile = authState.profile;

    if (userProfile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE96A92))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Mon compte',
          style: TextStyle(
            color: Color(0xFF2C2C2C),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            _buildProfileHeader(userProfile.nom, userProfile.telephone, userProfile.email),
            const SizedBox(height: 32),
            _buildMenuItems(context, ref, userProfile.adresses, userProfile.role),
            const SizedBox(height: 24),
            _buildLogoutButton(context, ref),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String nom, String telephone, String email) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 40,
          backgroundColor: Color(0xFFF0F0F0),
          child: Icon(Icons.person, size: 40, color: Color(0xFF8E8E93)),
        ),
        const SizedBox(height: 16),
        Text(
          nom,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C2C2C),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$telephone\n$email',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF8E8E93),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItems(BuildContext context, WidgetRef ref, List adresses, String role) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Accès espace admin — visible uniquement pour role == "admin"
            if (role == 'admin') ...[
              _MenuItem(
                icon: Icons.admin_panel_settings_rounded,
                title: 'Espace Admin',
                iconColor: const Color(0xFFE96A92),
                onTap: () => context.push('/admin'),
              ),
              const Divider(height: 1, indent: 56),
            ],
            _MenuItem(
              icon: Icons.shopping_bag_outlined,
              title: 'Mes commandes',
              onTap: () => context.push('/orders'),
            ),
            const Divider(height: 1, indent: 56),
            ExpansionTile(
              leading: const Icon(Icons.location_on_outlined, color: Color(0xFF2C2C2C)),
              title: const Text(
                'Mes adresses',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2C2C2C),
                ),
              ),
              children: [
                if (adresses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Aucune adresse enregistrée.', style: TextStyle(color: Color(0xFF8E8E93))),
                  )
                else
                  ...adresses.map((addr) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 56),
                    title: Text(addr.label, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${addr.commune} - ${addr.details}'),
                  )),
              ],
            ),
            const Divider(height: 1, indent: 56),
            _MenuItem(
              icon: Icons.favorite_border,
              title: 'Mes favoris',
              onTap: () => context.push('/coming-soon'),
            ),
            const Divider(height: 1, indent: 56),
            _MenuItem(
              icon: Icons.notifications_none,
              title: 'Notifications',
              onTap: () => context.push('/coming-soon'),
            ),
            const Divider(height: 1, indent: 56),
            _MenuItem(
              icon: Icons.help_outline,
              title: 'Aide & FAQ',
              onTap: () => context.push('/coming-soon'),
            ),
            const Divider(height: 1, indent: 56),
            _MenuItem(
              icon: Icons.settings_outlined,
              title: 'Paramètres',
              onTap: () => context.push('/coming-soon'),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextButton.icon(
        onPressed: () async {
          await ref.read(authProvider.notifier).logout();
          if (context.mounted) {
            context.go('/login');
          }
        },
        icon: const Icon(Icons.logout, color: Color(0xFFE96A92)),
        label: const Text(
          'Déconnexion',
          style: TextStyle(
            color: Color(0xFFE96A92),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? const Color(0xFF2C2C2C)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: iconColor ?? const Color(0xFF2C2C2C),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF8E8E93)),
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
    return DateFormat('d MMM yyyy', 'fr_FR').format(date);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final uid = ref.read(authProvider).user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton.icon(
            onPressed: uid == null
                ? null
                : () async {
                    await markAllNotificationsAsRead(uid);
                  },
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('Tout lire'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaire),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded,
                      size: 72, color: AppColors.secondaire.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune notification',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppColors.secondaire),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vous serez notifié ici des mises à jour de vos commandes.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.secondaire.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return _NotificationTile(
                notif: notif,
                relativeDate: _relativeDate(notif.createdAt),
                onTap: () async {
                  // Marquer comme lue
                  if (!notif.lu && uid != null) {
                    await markNotificationAsRead(uid, notif.id);
                  }
                  // Naviguer vers la commande si order_id présent
                  if (notif.orderId != null && context.mounted) {
                    context.push('/order/${notif.orderId}');
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notif;
  final String relativeDate;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notif,
    required this.relativeDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: notif.lu ? Colors.transparent : AppColors.primaireClair.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône avec indicateur non lu
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaireClair.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: AppColors.primaire,
                    size: 22,
                  ),
                ),
                if (!notif.lu)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.primaire,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Contenu texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.titre,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: notif.lu ? FontWeight.normal : FontWeight.bold,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        relativeDate,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.secondaire,
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.corps,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaire,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notif.orderId != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Voir la commande →',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primaire,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

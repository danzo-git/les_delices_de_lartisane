import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/order.dart';
import '../../../models/user_profile.dart';
import '../../../theme/app_colors.dart';
import '../providers/admin_dashboard_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(adminDashboardOrdersProvider);
    final usersAsync = ref.watch(adminDashboardUsersProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Tableau de bord',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () {
              ref.invalidate(adminDashboardOrdersProvider);
              ref.invalidate(adminDashboardUsersProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaire),
        ),
        error: (_, _) => _LoadError(
          onRetry: () => ref.invalidate(adminDashboardOrdersProvider),
        ),
        data: (orders) => usersAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaire),
          ),
          error: (_, _) => _LoadError(
            onRetry: () => ref.invalidate(adminDashboardUsersProvider),
          ),
          data: (users) => _DashboardContent(orders: orders, users: users),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final List<OrderModel> orders;
  final List<UserProfile> users;
  const _DashboardContent({required this.orders, required this.users});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month);
    final todaysOrders = orders
        .where((o) => _onOrAfter(o.createdAt, today))
        .length;
    final thisMonthOrders = orders
        .where((o) => _onOrAfter(o.createdAt, monthStart))
        .length;
    final newUsers = users
        .where((u) => _onOrAfter(u.createdAt, monthStart))
        .length;
    final waiting = orders
        .where((o) => o.statutCommande == 'en_attente_validation')
        .length;
    final paid = orders.where((o) => o.statutPaiement == 'confirme').toList();
    final revenue = paid.fold<double>(0, (sum, order) => sum + order.total);
    final average = paid.isEmpty ? 0.0 : revenue / paid.length;
    final recent = orders.take(5).toList();
    final weekly = List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return _DayCount(
        day,
        orders
            .where(
              (o) =>
                  o.createdAt != null &&
                  o.createdAt!.year == day.year &&
                  o.createdAt!.month == day.month &&
                  o.createdAt!.day == day.day,
            )
            .length,
      );
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final columns = constraints.maxWidth >= 1050 ? 4 : 2;
        return ListView(
          padding: EdgeInsets.all(wide ? 28 : 16),
          children: [
            Text(
              'Bonjour 👋',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.texte,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(now),
              style: const TextStyle(color: AppColors.secondaire),
            ),
            const SizedBox(height: 22),
            _MetricGrid(
              columns: columns,
              children: [
                _MetricCard(
                  title: 'Commandes',
                  value: '${orders.length}',
                  subtitle:
                      '$todaysOrders aujourd’hui · $thisMonthOrders ce mois',
                  icon: Icons.receipt_long_rounded,
                  tint: const Color(0xFFFFEEF3),
                ),
                _MetricCard(
                  title: 'À traiter',
                  value: '$waiting',
                  subtitle: 'En attente de validation',
                  icon: Icons.pending_actions_rounded,
                  tint: const Color(0xFFFFF4DE),
                  onTap: () => context.go('/admin/commandes'),
                ),
                _MetricCard(
                  title: 'Chiffre encaissé',
                  value: _money(revenue),
                  subtitle:
                      '${paid.length} paiement${paid.length > 1 ? 's' : ''} confirmé${paid.length > 1 ? 's' : ''}',
                  icon: Icons.payments_rounded,
                  tint: const Color(0xFFE8F7EF),
                ),
                _MetricCard(
                  title: 'Clients',
                  value: '${users.where((u) => u.role != 'admin').length}',
                  subtitle: '+$newUsers ce mois',
                  icon: Icons.people_alt_rounded,
                  tint: const Color(0xFFEAF1FF),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _MetricGrid(
              columns: wide ? 2 : 1,
              children: [
                _Panel(
                  title: 'Activité des 7 derniers jours',
                  trailing: 'Commandes',
                  child: _WeeklyChart(days: weekly),
                ),
                _Panel(
                  title: 'Vue rapide',
                  child: Column(
                    children: [
                      _QuickRow(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Panier moyen encaissé',
                        value: _money(average),
                      ),
                      const Divider(height: 22),
                      _QuickRow(
                        icon: Icons.local_shipping_outlined,
                        title: 'Livraisons',
                        value:
                            '${orders.where((o) => o.modeLivraison == 'livraison').length}',
                      ),
                      const Divider(height: 22),
                      _QuickRow(
                        icon: Icons.storefront_outlined,
                        title: 'Retraits en boutique',
                        value:
                            '${orders.where((o) => o.modeLivraison == 'retrait').length}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Panel(
              title: 'Commandes récentes',
              trailingWidget: TextButton(
                onPressed: () => context.go('/admin/commandes'),
                child: const Text('Tout voir'),
              ),
              child: recent.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: Text(
                          'Les nouvelles commandes apparaîtront ici.',
                          style: TextStyle(color: AppColors.secondaire),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < recent.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _RecentOrder(order: recent[i]),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

bool _onOrAfter(DateTime? date, DateTime start) =>
    date != null && !date.isBefore(start);
String _money(double value) =>
    '${NumberFormat('#,##0', 'fr_FR').format(value)} FCFA';

class _MetricGrid extends StatelessWidget {
  final int columns;
  final List<Widget> children;
  const _MetricGrid({required this.columns, required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 12.0;
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  final String title, value, subtitle;
  final IconData icon;
  final Color tint;
  final VoidCallback? onTap;
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.tint,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primaire, size: 21),
                ),
                const Spacer(),
                if (onTap != null)
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: AppColors.secondaire,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: AppColors.texte,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.texte,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.secondaire),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget? trailingWidget;
  final Widget child;
  const _Panel({
    required this.title,
    required this.child,
    this.trailing,
    this.trailingWidget,
  });
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trailingWidget != null)
                trailingWidget!
              else if (trailing != null)
                Text(
                  trailing!,
                  style: const TextStyle(
                    color: AppColors.secondaire,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _DayCount {
  final DateTime day;
  final int count;
  const _DayCount(this.day, this.count);
}

class _WeeklyChart extends StatelessWidget {
  final List<_DayCount> days;
  const _WeeklyChart({required this.days});
  @override
  Widget build(BuildContext context) {
    final maxCount = days.fold<int>(
      0,
      (max, item) => item.count > max ? item.count : max,
    );
    return SizedBox(
      height: 145,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((item) {
          final height = maxCount == 0 ? 5.0 : 78 * item.count / maxCount;
          final isToday =
              item.day.year == DateTime.now().year &&
              item.day.month == DateTime.now().month &&
              item.day.day == DateTime.now().day;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${item.count}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.secondaire,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  height: height,
                  width: 20,
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppColors.primaire
                        : AppColors.primaireClair,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  DateFormat('E', 'fr_FR').format(item.day).substring(0, 2),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.secondaire,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _QuickRow extends StatelessWidget {
  final IconData icon;
  final String title, value;
  const _QuickRow({
    required this.icon,
    required this.title,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: AppColors.primaire),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 12, color: AppColors.secondaire),
        ),
      ),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ],
  );
}

class _RecentOrder extends StatelessWidget {
  final OrderModel order;
  const _RecentOrder({required this.order});
  @override
  Widget build(BuildContext context) {
    final status = switch (order.statutCommande) {
      'en_attente_validation' => ('En attente', const Color(0xFFFFF2D8)),
      'en_preparation' => ('En préparation', const Color(0xFFEAF1FF)),
      'prete' => ('Prête', const Color(0xFFE8F7EF)),
      'livree' => ('Livrée', const Color(0xFFE8F7EF)),
      'refusee' => ('Refusée', const Color(0xFFFFE9E9)),
      'annulee' => ('Annulée', const Color(0xFFF0F0F0)),
      _ => ('Acceptée', const Color(0xFFEAF1FF)),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            color: AppColors.primaire,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande #${order.numero}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${order.clientNom} · ${order.createdAt == null ? 'Date inconnue' : DateFormat('dd/MM · HH:mm').format(order.createdAt!)}',
                  style: const TextStyle(
                    color: AppColors.secondaire,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: status.$2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.$1,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            _money(order.total),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final VoidCallback onRetry;
  const _LoadError({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: AppColors.secondaire,
            size: 42,
          ),
          const SizedBox(height: 12),
          const Text('Impossible de charger les données du tableau de bord.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}

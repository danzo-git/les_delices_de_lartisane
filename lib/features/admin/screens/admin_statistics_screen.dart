import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/order.dart';
import '../../../theme/app_colors.dart';
import '../providers/admin_dashboard_provider.dart';

class AdminStatisticsScreen extends ConsumerWidget {
  const AdminStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(adminDashboardOrdersProvider);
    final users = ref.watch(adminDashboardUsersProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Statistiques',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: orders.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaire),
        ),
        error: (_, _) =>
            _Retry(onRetry: () => ref.invalidate(adminDashboardOrdersProvider)),
        data: (items) => users.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaire),
          ),
          error: (_, _) => _Retry(
            onRetry: () => ref.invalidate(adminDashboardUsersProvider),
          ),
          data: (clients) =>
              _StatisticsContent(
                orders: items,
                users: clients.where((user) => user.role != 'admin').length,
              ),
        ),
      ),
    );
  }
}

class _StatisticsContent extends StatelessWidget {
  final List<OrderModel> orders;
  final int users;
  const _StatisticsContent({required this.orders, required this.users});

  @override
  Widget build(BuildContext context) {
    final paid = orders.where((o) => o.statutPaiement == 'confirme');
    final revenue = paid.fold<double>(0, (sum, o) => sum + o.total);
    final counts = <String, int>{
      'En attente': orders
          .where((o) => o.statutCommande == 'en_attente_validation')
          .length,
      'Acceptées': orders.where((o) => o.statutCommande == 'acceptee').length,
      'En préparation': orders
          .where((o) => o.statutCommande == 'en_preparation')
          .length,
      'Prêtes': orders.where((o) => o.statutCommande == 'prete').length,
      'Livrées': orders.where((o) => o.statutCommande == 'livree').length,
      'Refusées / annulées': orders
          .where(
            (o) =>
                o.statutCommande == 'refusee' || o.statutCommande == 'annulee',
          )
          .length,
    };
    final popular = <String, int>{};
    for (final order in orders) {
      for (final item in order.items) {
        popular[item.nom] = (popular[item.nom] ?? 0) + item.quantite;
      }
    }
    final bestsellers = popular.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = counts.values.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Vue d’ensemble de votre activité',
          style: TextStyle(color: AppColors.secondaire),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryTile(
              label: 'Clients inscrits',
              value: '$users',
              icon: Icons.people_alt_outlined,
            ),
            _SummaryTile(
              label: 'Commandes',
              value: '${orders.length}',
              icon: Icons.receipt_long_outlined,
            ),
            _SummaryTile(
              label: 'Paiements confirmés',
              value: '${paid.length}',
              icon: Icons.check_circle_outline_rounded,
            ),
            _SummaryTile(
              label: 'Montant encaissé',
              value: '${NumberFormat('#,##0', 'fr_FR').format(revenue)} FCFA',
              icon: Icons.payments_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _WhitePanel(
          title: 'Commandes par statut',
          child: Column(
            children: counts.entries.map((entry) {
              final fraction = maxCount == 0 ? 0.0 : entry.value / maxCount;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          '${entry.value}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFF1F1F1),
                        color: AppColors.primaire,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        _WhitePanel(
          title: 'Produits les plus commandés',
          child: bestsellers.isEmpty
              ? const Text(
                  'Les produits commandés apparaîtront ici.',
                  style: TextStyle(color: AppColors.secondaire),
                )
              : Column(
                  children: [
                    for (var i = 0; i < bestsellers.take(5).length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.fond,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  color: AppColors.primaire,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                bestsellers[i].key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${bestsellers[i].value} vendu${bestsellers[i].value > 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: AppColors.secondaire,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _WhitePanel(
          title: 'Modes de réception',
          child: Row(
            children: [
              Expanded(
                child: _DeliveryCount(
                  label: 'Livraison',
                  icon: Icons.local_shipping_outlined,
                  count: orders
                      .where((o) => o.modeLivraison == 'livraison')
                      .length,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DeliveryCount(
                  label: 'Retrait',
                  icon: Icons.storefront_outlined,
                  count: orders
                      .where((o) => o.modeLivraison == 'retrait')
                      .length,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width:
        (MediaQuery.sizeOf(context).width - 48) /
        (MediaQuery.sizeOf(context).width >= 760 ? 4 : 2),
    child: Card(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primaire),
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.secondaire),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WhitePanel extends StatelessWidget {
  final String title;
  final Widget child;
  const _WhitePanel({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _DeliveryCount extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  const _DeliveryCount({
    required this.label,
    required this.icon,
    required this.count,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FA),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primaire, size: 19),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

class _Retry extends StatelessWidget {
  final VoidCallback onRetry;
  const _Retry({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Les statistiques ne sont pas disponibles.'),
        TextButton(onPressed: onRetry, child: const Text('Réessayer')),
      ],
    ),
  );
}

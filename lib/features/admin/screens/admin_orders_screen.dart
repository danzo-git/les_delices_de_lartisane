import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/order.dart';
import '../../../theme/app_colors.dart';
import '../providers/admin_orders_provider.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  // Filtres disponibles : libellé affiché → valeur Firestore
  static const List<_FilterOption> _filters = [
    _FilterOption(label: 'Toutes', value: ''),
    _FilterOption(label: 'En attente', value: 'en_attente_validation'),
    _FilterOption(label: 'Acceptées', value: 'acceptee'),
    _FilterOption(label: 'En préparation', value: 'en_preparation'),
    _FilterOption(label: 'Prêtes', value: 'prete'),
    _FilterOption(label: 'Livrées', value: 'livree'),
    _FilterOption(label: 'Refusées', value: 'refusee'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentFilter = ref.watch(adminOrderStatusFilterProvider);
    final ordersAsync = ref.watch(adminOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestion des commandes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.texte,
                  ),
            ),
            ordersAsync.when(
              data: (orders) => Text(
                '${orders.length} commande${orders.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.secondaire,
                    ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _buildFilterChips(currentFilter),
        ),
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return _buildEmptyState(currentFilter);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              return _OrderCard(
                order: orders[index],
                onTap: () => _showOrderDetail(context, orders[index]),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaire),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text('Erreur de chargement', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(error.toString(), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(String currentFilter) {
    return Container(
      color: Colors.white,
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = filter.value == currentFilter;
          return FilterChip(
            label: Text(filter.label),
            selected: isSelected,
            onSelected: (_) {
              ref.read(adminOrderStatusFilterProvider.notifier).state = filter.value;
            },
            selectedColor: AppColors.primaire,
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppColors.texte,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected ? AppColors.primaire : AppColors.secondaire.withValues(alpha: 0.3),
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String currentFilter) {
    final filterLabel = _filters.firstWhere((f) => f.value == currentFilter).label;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.fond,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 40,
                color: AppColors.primaire,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              currentFilter.isEmpty
                  ? 'Aucune commande pour l\'instant'
                  : 'Aucune commande "${filterLabel.toLowerCase()}"',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.texte,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Les commandes apparaîtront ici dès qu\'elles seront passées.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaire,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetail(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(order: order),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// CARD COMMANDE dans la liste
// ──────────────────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = order.createdAt != null
        ? DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(order.createdAt!)
        : '—';

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.secondaire.withValues(alpha: 0.12)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Commande #${order.numero}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.clientNom,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.secondaire,
                              ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(statut: order.statutCommande),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.shopping_bag_outlined,
                    label: '${order.items.length} article${order.items.length > 1 ? 's' : ''}',
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: order.modeLivraison == 'livraison'
                        ? Icons.delivery_dining_rounded
                        : Icons.storefront_rounded,
                    label: order.modeLivraison == 'livraison' ? 'Livraison' : 'Retrait',
                  ),
                  const Spacer(),
                  Text(
                    '${NumberFormat('#,###', 'fr_FR').format(order.total.toInt())} FCFA',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaire,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 13, color: AppColors.secondaire),
                  const SizedBox(width: 4),
                  Text(
                    dateStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaire,
                          fontSize: 11,
                        ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 18, color: AppColors.secondaire),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// FEUILLE DE DÉTAIL D'UNE COMMANDE
// ──────────────────────────────────────────────────────────────────────────────
class _OrderDetailSheet extends ConsumerStatefulWidget {
  final OrderModel order;

  const _OrderDetailSheet({required this.order});

  @override
  ConsumerState<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends ConsumerState<_OrderDetailSheet> {
  bool _isLoading = false;
  final TextEditingController _motifController = TextEditingController();

  @override
  void dispose() {
    _motifController.dispose();
    super.dispose();
  }

  Future<void> _updateOrderStatus({
    required String newStatut,
    String? motifRefus,
    String? historyLabel,
  }) async {
    setState(() => _isLoading = true);
    try {
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id);

      final historyEntry = {
        'statut': historyLabel ?? newStatut,
        'date': Timestamp.now(),
      };

      final Map<String, dynamic> updateData = {
        'statut_commande': newStatut,
        'historique_statuts': FieldValue.arrayUnion([historyEntry]),
      };

      if (motifRefus != null) {
        updateData['motif_refus'] = motifRefus;
      }

      await orderRef.update(updateData);

      if (mounted) {
        Navigator.of(context).pop(); // Ferme la feuille de détail
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Commande #${widget.order.numero} mise à jour.'),
            backgroundColor: AppColors.succes,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleAccept() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Accepter la commande ?'),
        content: Text(
          'La commande #${widget.order.numero} de ${widget.order.clientNom} sera acceptée.\n\n'
          'Le client pourra ensuite procéder au paiement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.succes,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Accepter'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _updateOrderStatus(
        newStatut: 'acceptee',
        historyLabel: 'commande_acceptee',
      );
    }
  }

  Future<void> _handleRefuse() async {
    _motifController.clear();
    final motif = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Refuser la commande'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Veuillez indiquer le motif du refus pour la commande #${widget.order.numero}.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _motifController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ex : Ingrédients indisponibles, délai impossible...',
                labelText: 'Motif du refus *',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final motif = _motifController.text.trim();
              if (motif.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Le motif est obligatoire.')),
                );
                return;
              }
              Navigator.of(ctx).pop(motif);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );

    if (motif != null && motif.isNotEmpty) {
      await _updateOrderStatus(
        newStatut: 'refusee',
        motifRefus: motif,
        historyLabel: 'commande_refusee',
      );
    }
  }

  Future<void> _advanceStatus(String nextStatut, String historyLabel) async {
    final labels = {
      'en_preparation': 'Commencer la préparation',
      'prete': 'Marquer comme prête',
      'livree': 'Marquer comme livrée',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(labels[nextStatut] ?? 'Confirmer'),
        content: Text('Commande #${widget.order.numero} — confirmer cette action ?'),
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
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _updateOrderStatus(newStatut: nextStatut, historyLabel: historyLabel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final currencyFormat = NumberFormat('#,###', 'fr_FR');

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Poignée
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.secondaire.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Commande #${order.numero}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.clientNom,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.secondaire,
                                ),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(statut: order.statutCommande),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Contenu défilant
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ARTICLES
                    _SectionHeader(icon: Icons.shopping_bag_outlined, title: 'Articles commandés'),
                    const SizedBox(height: 12),
                    ...order.items.map((item) => _OrderItemRow(item: item)),
                    const Divider(height: 24),
                    // Résumé financier
                    _SummaryRow(label: 'Sous-total', value: '${currencyFormat.format(order.sousTotal.toInt())} FCFA'),
                    _SummaryRow(label: 'Frais de livraison', value: '${currencyFormat.format(order.fraisLivraison.toInt())} FCFA'),
                    const SizedBox(height: 4),
                    _SummaryRow(
                      label: 'Total',
                      value: '${currencyFormat.format(order.total.toInt())} FCFA',
                      isBold: true,
                    ),

                    const SizedBox(height: 20),

                    // INFORMATIONS DE LIVRAISON
                    _SectionHeader(icon: Icons.local_shipping_outlined, title: 'Informations de livraison'),
                    const SizedBox(height: 12),
                    _InfoRow(
                      label: 'Mode',
                      value: order.modeLivraison == 'livraison' ? 'Livraison à domicile' : 'Retrait en boutique',
                    ),
                    if (order.commune != null)
                      _InfoRow(label: 'Commune', value: order.commune!),
                    if (order.adresseLivraison != null && order.adresseLivraison!.isNotEmpty)
                      _InfoRow(label: 'Adresse précise', value: order.adresseLivraison!),
                    if (order.dateSouhaitee != null)
                      _InfoRow(
                        label: 'Date/heure souhaitée',
                        value: DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr_FR').format(order.dateSouhaitee!),
                      ),

                    const SizedBox(height: 20),

                    // STATUT DU PAIEMENT
                    _SectionHeader(icon: Icons.payment_rounded, title: 'Paiement'),
                    const SizedBox(height: 12),
                    _InfoRow(label: 'Mode', value: order.modePaiement.replaceAll('_', ' ')),
                    Row(
                      children: [
                        Text(
                          'Statut : ',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.secondaire,
                              ),
                        ),
                        _PaiementBadge(statut: order.statutPaiement),
                      ],
                    ),

                    if (order.motifRefus != null && order.motifRefus!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionHeader(icon: Icons.info_outline, title: 'Motif du refus'),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          order.motifRefus!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.red.shade700,
                              ),
                        ),
                      ),
                    ],

                    if (order.historiqueStatuts.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionHeader(icon: Icons.timeline_rounded, title: 'Historique'),
                      const SizedBox(height: 12),
                      ...order.historiqueStatuts.reversed.map((h) => _HistoryRow(history: h)),
                    ],

                    const SizedBox(height: 24),

                    // ZONE D'ACTIONS ADMIN
                    _buildActionZone(order),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionZone(OrderModel order) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AppColors.primaire),
        ),
      );
    }

    // ─── en_attente_validation : Accepter / Refuser ───────────────────────────
    if (order.statutCommande == 'en_attente_validation') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(icon: Icons.admin_panel_settings_rounded, title: 'Actions'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _handleAccept,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Accepter la commande'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.succes,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _handleRefuse,
            icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
            label: const Text('Refuser la commande', style: TextStyle(color: Colors.redAccent)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      );
    }

    // ─── acceptee + paiement confirme → Commencer la préparation ─────────────
    if (order.statutCommande == 'acceptee') {
      if (order.statutPaiement == 'confirme') {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(icon: Icons.admin_panel_settings_rounded, title: 'Actions'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _advanceStatus('en_preparation', 'mise_en_preparation'),
              icon: const Icon(Icons.kitchen_rounded),
              label: const Text('Commencer la préparation'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        );
      } else {
        // Paiement non encore confirmé
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'En attente du paiement du client',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        );
      }
    }

    // ─── en_preparation → prete ───────────────────────────────────────────────
    if (order.statutCommande == 'en_preparation' && order.statutPaiement == 'confirme') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(icon: Icons.admin_panel_settings_rounded, title: 'Actions'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _advanceStatus('prete', 'commande_prete'),
            icon: const Icon(Icons.check_box_rounded),
            label: const Text('Marquer comme prête'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      );
    }

    // ─── prete → livree ───────────────────────────────────────────────────────
    if (order.statutCommande == 'prete' && order.statutPaiement == 'confirme') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(icon: Icons.admin_panel_settings_rounded, title: 'Actions'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _advanceStatus('livree', 'commande_livree'),
            icon: const Icon(Icons.local_shipping_rounded),
            label: const Text('Marquer comme livrée'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.succes,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      );
    }

    // Pas d'action disponible (livree, refusee, ou paiement non confirmé pour en_preparation/prete)
    return const SizedBox.shrink();
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// COMPOSANTS UTILITAIRES
// ──────────────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String statut;

  const _StatusBadge({required this.statut});

  static const Map<String, _BadgeConfig> _config = {
    'en_attente_validation': _BadgeConfig(label: 'En attente', bg: Color(0xFFFFF3CD), text: Color(0xFF856404)),
    'acceptee': _BadgeConfig(label: 'Acceptée', bg: Color(0xFFD1ECF1), text: Color(0xFF0C5460)),
    'en_preparation': _BadgeConfig(label: 'En préparation', bg: Color(0xFFCCE5FF), text: Color(0xFF004085)),
    'prete': _BadgeConfig(label: 'Prête', bg: Color(0xFFD4EDDA), text: Color(0xFF155724)),
    'livree': _BadgeConfig(label: 'Livrée', bg: Color(0xFF3CB371), text: Colors.white),
    'refusee': _BadgeConfig(label: 'Refusée', bg: Color(0xFFF8D7DA), text: Color(0xFF721C24)),
    'recue': _BadgeConfig(label: 'Reçue', bg: Color(0xFFE2E3E5), text: Color(0xFF383D41)),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _config[statut] ?? const _BadgeConfig(label: 'Inconnue', bg: Color(0xFFE2E3E5), text: Color(0xFF383D41));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        cfg.label,
        style: TextStyle(
          color: cfg.text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BadgeConfig {
  final String label;
  final Color bg;
  final Color text;
  const _BadgeConfig({required this.label, required this.bg, required this.text});
}

class _PaiementBadge extends StatelessWidget {
  final String statut;
  const _PaiementBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    Color bg, text;
    String label;
    switch (statut) {
      case 'confirme':
        bg = const Color(0xFFD4EDDA); text = const Color(0xFF155724); label = 'Confirmé';
        break;
      case 'en_attente':
        bg = const Color(0xFFFFF3CD); text = const Color(0xFF856404); label = 'En attente';
        break;
      case 'echoue':
        bg = const Color(0xFFF8D7DA); text = const Color(0xFF721C24); label = 'Échoué';
        break;
      case 'non_requis':
        bg = const Color(0xFFE2E3E5); text = const Color(0xFF383D41); label = 'Non requis';
        break;
      default:
        bg = const Color(0xFFE2E3E5); text = const Color(0xFF383D41); label = statut;
    }
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaire),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.texte,
              ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaire,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  const _SummaryRow({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isBold ? AppColors.texte : AppColors.secondaire,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  )),
          Text(value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    color: isBold ? AppColors.primaire : AppColors.texte,
                  )),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final OrderItem item;
  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###', 'fr_FR');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.fond,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '×${item.quantite}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primaire,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nom,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        )),
                if (item.optionLabel.isNotEmpty)
                  Text(item.optionLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.secondaire,
                          )),
              ],
            ),
          ),
          Text(
            '${currencyFormat.format(item.sousTotal.toInt())} FCFA',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final OrderStatusHistory history;
  const _HistoryRow({required this.history});

  @override
  Widget build(BuildContext context) {
    final dateStr = history.date != null
        ? DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(history.date!)
        : '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: const BoxDecoration(
              color: AppColors.primaire,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  history.statut.replaceAll('_', ' '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.texte,
                      ),
                ),
                Text(
                  dateStr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaire,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.secondaire),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.secondaire,
                fontSize: 12,
              ),
        ),
      ],
    );
  }
}

class _FilterOption {
  final String label;
  final String value;
  const _FilterOption({required this.label, required this.value});
}

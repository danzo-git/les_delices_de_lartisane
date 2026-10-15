import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/cart_item.dart';
import '../../../models/order.dart';
import '../../../models/product.dart';
import '../../../services/firestore_service.dart';
import '../../panier/providers/panier_provider.dart';
import '../providers/order_provider.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(userOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C2C2C)),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'Mes commandes',
          style: TextStyle(
            color: Color(0xFF2C2C2C),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF2C2C2C)),
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('Aucune commande trouvée.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = orders[index];
              final productIds = order.items
                  .map((item) => item.productId)
                  .where((id) => id.isNotEmpty)
                  .toSet();
              final hasUnreviewedProduct = productIds.any(
                (id) => !order.reviewedProductIds.contains(id),
              );
              return InkWell(
                onTap: () => context.push('/order/${order.id}'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Commande #${order.numero}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C2C2C),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  order.createdAt != null
                                      ? DateFormat(
                                          'dd MMM yyyy',
                                          'fr_FR',
                                        ).format(order.createdAt!)
                                      : '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF8E8E93),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildStatusBadge(order.statutCommande),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${order.total.toInt()} FCFA',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE96A92),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF8E8E93),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (order.items.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (order.statutCommande == 'livree') ...[
                                TextButton.icon(
                                  onPressed: () =>
                                      context.push('/order/${order.id}/avis'),
                                  icon: const Icon(Icons.rate_review_outlined),
                                  label: Text(
                                    hasUnreviewedProduct
                                        ? 'Donner mon avis'
                                        : 'Avis envoyés',
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              _OrderReorderButton(order: order),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFE96A92)),
        ),
        error: (err, stack) => Center(child: Text('Erreur: $err')),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'recue':
        bgColor = const Color(0xFFF0F0F0);
        textColor = const Color(0xFF8E8E93);
        label = 'Reçue';
        break;
      case 'en_preparation':
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFFF9800);
        label = 'En préparation';
        break;
      case 'prete':
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF4CAF50);
        label = 'Prête';
        break;
      case 'en_attente_validation':
        bgColor = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF2196F3);
        label = 'En attente';
        break;
      case 'acceptee':
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF4CAF50);
        label = 'Acceptée (à payer)';
        break;
      case 'annulee':
      case 'refusee':
        bgColor = const Color(0xFFFFEBEE);
        textColor = const Color(0xFFF44336);
        label = status == 'annulee' ? 'Annulée' : 'Refusée';
        break;
      case 'livree':
        bgColor = const Color(
          0xFFE8F5E9,
        ); // Match "Succès" color from design system if different
        textColor = const Color(0xFF3C8371);
        label = 'Livrée';
        break;
      default:
        bgColor = const Color(0xFFF0F0F0);
        textColor = const Color(0xFF8E8E93);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _OrderReorderButton extends ConsumerStatefulWidget {
  const _OrderReorderButton({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_OrderReorderButton> createState() =>
      _OrderReorderButtonState();
}

class _OrderReorderButtonState extends ConsumerState<_OrderReorderButton> {
  bool _isLoading = false;

  Future<void> _reorder() async {
    setState(() => _isLoading = true);
    try {
      final productIds = widget.order.items
          .map((item) => item.productId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final service = FirestoreService();
      final currentProducts = await Future.wait(
        productIds.map(service.getProduct),
      );
      final productsById = Map<String, Product?>.fromIterables(
        productIds,
        currentProducts,
      );

      var addedCount = 0;
      var skippedCount = 0;
      final cart = ref.read(panierProvider.notifier);
      for (final item in widget.order.items) {
        final product = productsById[item.productId];
        if (product == null || !product.disponible) {
          skippedCount++;
          continue;
        }
        final matchingOptions = product.options.where(
          (option) => option.label == item.optionLabel,
        );
        if (matchingOptions.isEmpty) {
          skippedCount++;
          continue;
        }

        final option = matchingOptions.first;
        cart.ajouterArticle(
          CartItem(
            productId: product.id,
            nom: product.nom,
            optionLabel: option.label,
            prixUnitaire: option.prix,
            quantite: item.quantite,
            sousTotal: option.prix * item.quantite,
            imageUrl: product.imageUrl,
          ),
        );
        addedCount++;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      final message = addedCount == 0
          ? 'Aucun produit de cette commande n’est disponible actuellement.'
          : skippedCount == 0
          ? 'Panier mis à jour avec les prix actuels.'
          : 'Panier mis à jour. $skippedCount produit(s) indisponible(s) ou option(s) modifiée(s) ignoré(s).';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      if (addedCount > 0) context.go('/panier');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de recommander cette commande.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _isLoading ? null : _reorder,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.replay_rounded),
      label: const Text('Recommander'),
    );
  }
}

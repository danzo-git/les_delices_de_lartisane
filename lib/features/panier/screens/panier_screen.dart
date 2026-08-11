import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_colors.dart';
import '../providers/panier_provider.dart';
import '../providers/delivery_provider.dart';

class PanierScreen extends ConsumerWidget {
  const PanierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(panierProvider);
    final deliveryFeesAsync = ref.watch(deliveryFeesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon panier', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.texte,
      ),
      body: cartState.items.isEmpty
          ? const Center(child: Text('Votre panier est vide.', style: TextStyle(color: AppColors.secondaire)))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartState.items.length,
                    itemBuilder: (context, index) {
                      final item = cartState.items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            // Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: item.imageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: item.imageUrl!,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) => _buildPlaceholder(),
                                    )
                                  : _buildPlaceholder(),
                            ),
                            const SizedBox(width: 16),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(item.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.close, color: AppColors.secondaire, size: 20),
                                        onPressed: () => ref.read(panierProvider.notifier).retirerArticle(item.productId, item.optionLabel),
                                      ),
                                    ],
                                  ),
                                  Text(item.optionLabel, style: const TextStyle(color: AppColors.secondaire, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${item.prixUnitaire.toInt()} FCFA', style: const TextStyle(fontWeight: FontWeight.w600)),
                                      // Quantité contrôles
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.fond,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove, size: 16, color: AppColors.primaire),
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              constraints: const BoxConstraints(),
                                              onPressed: () => ref.read(panierProvider.notifier).modifierQuantite(item.productId, item.optionLabel, item.quantite - 1),
                                            ),
                                            Text('${item.quantite}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                            IconButton(
                                              icon: const Icon(Icons.add, size: 16, color: AppColors.primaire),
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              constraints: const BoxConstraints(),
                                              onPressed: () => ref.read(panierProvider.notifier).modifierQuantite(item.productId, item.optionLabel, item.quantite + 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Section Mode de retrait et Livraison
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Mode de retrait', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRetraitOption(
                              context: context,
                              title: 'Retrait en boutique',
                              value: 'retrait',
                              groupValue: cartState.modeLivraison,
                              onChanged: (val) => ref.read(panierProvider.notifier).setModeLivraison(val!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildRetraitOption(
                              context: context,
                              title: 'Livraison',
                              value: 'livraison',
                              groupValue: cartState.modeLivraison,
                              onChanged: (val) => ref.read(panierProvider.notifier).setModeLivraison(val!),
                            ),
                          ),
                        ],
                      ),
                      
                      if (cartState.modeLivraison == 'livraison') ...[
                        const SizedBox(height: 16),
                        const Text('Commune de livraison', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        deliveryFeesAsync.when(
                          data: (fees) {
                            if (fees.isEmpty) return const Text('Aucune commune disponible');
                            return DropdownButtonFormField<String>(
                              value: cartState.commune,
                              hint: const Text('Sélectionnez une commune'),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              items: fees.map((fee) {
                                return DropdownMenuItem(
                                  value: fee.commune,
                                  child: Text('${fee.commune} (${fee.frais.toInt()} FCFA)'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  final selectedFee = fees.firstWhere((f) => f.commune == val);
                                  ref.read(panierProvider.notifier).setCommune(val, selectedFee.frais);
                                }
                              },
                            );
                          },
                          loading: () => const CircularProgressIndicator(),
                          error: (e, st) => Text('Erreur: $e'),
                        ),
                      ],

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sous-total', style: TextStyle(color: AppColors.secondaire)),
                          Text('${cartState.sousTotal.toInt()} FCFA', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Frais de livraison', style: TextStyle(color: AppColors.secondaire)),
                          Text(cartState.fraisLivraison > 0 ? '${cartState.fraisLivraison.toInt()} FCFA' : 'Gratuit', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text('${cartState.total.toInt()} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primaire)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (cartState.modeLivraison == 'livraison' && cartState.commune == null)
                              ? null
                              : () => context.push('/paiement'),
                          child: const Text('Commander', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: AppColors.fond,
      child: const Icon(Icons.cake, color: AppColors.primaire),
    );
  }

  Widget _buildRetraitOption({
    required BuildContext context,
    required String title,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.fond : Colors.white,
          border: Border.all(color: isSelected ? AppColors.primaire : Colors.grey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primaire : Colors.grey,
              size: 20,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.primaire : AppColors.texte,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

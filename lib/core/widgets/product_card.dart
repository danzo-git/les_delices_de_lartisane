import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product.dart';
import '../../theme/app_colors.dart';
import '../../models/cart_item.dart';
import '../../features/panier/providers/panier_provider.dart';

class ProductCard extends ConsumerWidget {
  final Product product;
  final VoidCallback onTap;

  /// Callback optionnel — si non fourni, le widget gère lui-même l'ajout au panier.
  final VoidCallback? onAddTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onAddTap,
  });

  void _addToCart(BuildContext context, WidgetRef ref) {
    if (product.options.isEmpty) return;

    // Option la moins chère = première après tri ascendant par prix
    final sortedOptions = List<ProductOption>.from(product.options)
      ..sort((a, b) => a.prix.compareTo(b.prix));
    final cheapestOption = sortedOptions.first;

    final item = CartItem(
      productId: product.id,
      nom: product.nom,
      optionLabel: cheapestOption.label,
      prixUnitaire: cheapestOption.prix,
      quantite: 1,
      sousTotal: cheapestOption.prix,
      imageUrl: product.imageUrl,
    );

    ref.read(panierProvider.notifier).ajouterArticle(item);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${product.nom} ajouté au panier',
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaire,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Voir',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Calcul du prix de départ (le plus bas)
    double startingPrice = 0.0;
    if (product.options.isNotEmpty) {
      startingPrice = product.options.map((o) => o.prix).reduce((a, b) => a < b ? a : b);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.fond,
                      child: const Icon(Icons.cake, color: AppColors.primaire, size: 40),
                    ),
                  ),
                ),
              ),
            ),
            
            // Infos
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nom,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  
                  // Note et avis
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${product.noteMoyenne} (${product.nombreAvis})',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Prix et Bouton Ajout
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${startingPrice.toInt()} FCFA',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primaire,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (onAddTap != null) {
                            onAddTap!();
                          } else {
                            _addToCart(context, ref);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primaire,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

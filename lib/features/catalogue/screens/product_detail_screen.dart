import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/product.dart';
import '../../../models/cart_item.dart';
import '../../../theme/app_colors.dart';
import '../providers/catalogue_provider.dart';
import '../../panier/providers/panier_provider.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  ProductOption? _selectedOption;
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productProvider(widget.productId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.texte),
              onPressed: () => context.pop(),
            ),
          ),
        ),
      ),
      body: productAsync.when(
        data: (product) {
          if (product == null) {
            return const Center(child: Text('Produit introuvable.'));
          }

          // Initialisation de l'option par défaut si non sélectionnée
          if (_selectedOption == null && product.options.isNotEmpty) {
            // Prendre l'option la moins chère par défaut
            _selectedOption = product.options.reduce((a, b) => a.prix < b.prix ? a : b);
          }

          final totalPrice = (_selectedOption?.prix ?? 0.0) * _quantity;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    SizedBox(
                      height: 300,
                      width: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.fond,
                          child: const Icon(Icons.cake, size: 80, color: AppColors.primaire),
                        ),
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Titre et Note
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  product.nom,
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${product.noteMoyenne} (${product.nombreAvis})',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          // Prix de départ
                          Text(
                            '${product.options.isNotEmpty ? product.options.map((o) => o.prix).reduce((a, b) => a < b ? a : b).toInt() : 0} FCFA',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppColors.primaire,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Description
                          Text(
                            product.description,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.secondaire,
                                  height: 1.5,
                                ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Accordéons Ingrédients / Allergènes
                          Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: const Text('Ingrédients', style: TextStyle(fontWeight: FontWeight.w600)),
                              tilePadding: EdgeInsets.zero,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Text(
                                    product.ingredients,
                                    style: const TextStyle(color: AppColors.secondaire),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: const Text('Allergènes', style: TextStyle(fontWeight: FontWeight.w600)),
                              tilePadding: EdgeInsets.zero,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Text(
                                    product.allergenes,
                                    style: const TextStyle(color: AppColors.secondaire),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Choix de la boîte
                          Text(
                            'Choix de la boîte',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          ...product.options.map((option) {
                            final isSelected = _selectedOption == option;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedOption = option;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected ? AppColors.primaire : Colors.grey.withValues(alpha: 0.3),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: isSelected ? AppColors.fond : Colors.white,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                          color: isSelected ? AppColors.primaire : Colors.grey,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(option.label, style: const TextStyle(fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    Text(
                                      '${option.prix.toInt()} FCFA',
                                      style: TextStyle(
                                        color: isSelected ? AppColors.primaire : AppColors.texte,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 24),

                          // Quantité
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Quantité',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.fond,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, color: AppColors.primaire),
                                      onPressed: () {
                                        if (_quantity > 1) {
                                          setState(() {
                                            _quantity--;
                                          });
                                        }
                                      },
                                    ),
                                    Text(
                                      '$_quantity',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, color: AppColors.primaire),
                                      onPressed: () {
                                        setState(() {
                                          _quantity++;
                                        });
                                      },
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
              ),

              // Barre flottante d'ajout au panier
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Total', style: TextStyle(color: AppColors.secondaire)),
                          Text(
                            '${totalPrice.toInt()} FCFA',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                        ),
                        onPressed: _selectedOption == null
                            ? null
                            : () {
                                // Ajout au panier via le provider
                                final itemToAdd = CartItem(
                                  productId: product.id,
                                  nom: product.nom,
                                  optionLabel: _selectedOption!.label,
                                  prixUnitaire: _selectedOption!.prix,
                                  quantite: _quantity,
                                  sousTotal: totalPrice,
                                  imageUrl: product.imageUrl,
                                );
                                
                                ref.read(panierProvider.notifier).ajouterArticle(itemToAdd);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${_quantity}x ${product.nom} (${_selectedOption!.label}) ajouté(s)'),
                                    backgroundColor: AppColors.succes,
                                  ),
                                );
                                context.pop();
                              },
                        child: const Text('Ajouter au panier'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erreur: $e')),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/product_card.dart';
import '../../../theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/catalogue_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userName = authState.profile?.nom ?? 'Client';
    final categoriesAsync = ref.watch(categoriesProvider);
    // Pour les "meilleures ventes", on prend simplement les produits sans filtre spécifique pour l'instant
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Bandeau de bienvenue
            SliverPadding(
              padding: const EdgeInsets.all(24.0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour, $userName 👋',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Que souhaitez-vous déguster aujourd\'hui ?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.secondaire,
                          ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Barre de recherche
                    TextField(
                      onChanged: (value) {
                        ref.read(searchQueryProvider.notifier).state = value;
                      },
                      decoration: const InputDecoration(
                        hintText: 'Rechercher une mignardise...',
                        prefixIcon: Icon(Icons.search, color: AppColors.secondaire),
                      ),
                      onSubmitted: (_) {
                        context.go('/catalogue');
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Bannière promo (optionnelle, selon maquette "Mignardises artisanales préparées avec passion")
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaireClair.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mignardises artisanales\npréparées avec passion',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaire,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => context.go('/catalogue'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(100, 40),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: const Text('Découvrir', style: TextStyle(fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Catégories
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Catégories',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          TextButton(
                            onPressed: () {
                              ref.read(selectedCategoryProvider.notifier).state = null;
                              context.go('/catalogue');
                            },
                            child: const Text('Voir tout'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: categoriesAsync.when(
                        data: (categories) {
                          if (categories.isEmpty) {
                            return const Center(child: Text('Aucune catégorie trouvée.'));
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 16),
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              return GestureDetector(
                                onTap: () {
                                  ref.read(selectedCategoryProvider.notifier).state = cat.id;
                                  context.go('/catalogue');
                                },
                                child: Column(
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: AppColors.fond,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.primaireClair, width: 1),
                                      ),
                                      alignment: Alignment.center,
                                      // Si on a des URL d'icônes on peut utiliser CachedNetworkImage ici.
                                      // Sinon on affiche une icône par défaut ou la première lettre.
                                      child: cat.icone != null && cat.icone!.startsWith('http')
                                          ? Image.network(cat.icone!, width: 32, height: 32)
                                          : Text(cat.nom.substring(0, 1).toUpperCase(), 
                                              style: const TextStyle(color: AppColors.primaire, fontSize: 24, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      cat.nom,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.texte,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, st) => Center(child: Text('Erreur: $e')),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Nos meilleures ventes
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nos meilleures ventes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(selectedCategoryProvider.notifier).state = null;
                        context.go('/catalogue');
                      },
                      child: const Text('Voir tout'),
                    ),
                  ],
                ),
              ),
            ),

            productsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: Text('Aucun produit disponible.')),
                    ),
                  );
                }
                
                // On prend les 4 premiers pour simuler les "meilleures ventes"
                final bestSellers = products.take(4).toList();

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = bestSellers[index];
                        return ProductCard(
                          product: product,
                          onTap: () {
                            context.push('/product/${product.id}');
                          },
                          onAddTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${product.nom} ajouté au panier')),
                            );
                            // TODO: Brancher la logique du vrai panier ici plus tard
                          },
                        );
                      },
                      childCount: bestSellers.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator())),
              ),
              error: (e, st) => SliverToBoxAdapter(
                child: Center(child: Padding(padding: EdgeInsets.all(40.0), child: Text('Erreur: $e'))),
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

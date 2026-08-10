import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import '../../../services/firestore_service.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

// --- CATÉGORIES ---
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final service = ref.read(firestoreServiceProvider);
  return await service.getCategories();
});

// --- FILTRES ---
final selectedCategoryProvider = StateProvider<String?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');

// --- PRODUITS ---
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final service = ref.read(firestoreServiceProvider);
  final categoryId = ref.watch(selectedCategoryProvider);
  
  // Récupère les produits (filtrés par catégorie depuis Firestore)
  var products = await service.getProducts(categoryId: categoryId);
  
  // Filtrage local par nom (recherche)
  final query = ref.watch(searchQueryProvider).toLowerCase();
  if (query.isNotEmpty) {
    products = products.where((p) => p.nom.toLowerCase().contains(query)).toList();
  }
  
  return products;
});

// --- PRODUIT UNIQUE ---
final productProvider = FutureProvider.family<Product?, String>((ref, productId) async {
  final service = ref.read(firestoreServiceProvider);
  return await service.getProduct(productId);
});

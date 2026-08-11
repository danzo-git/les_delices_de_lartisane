import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/cart_item.dart';

class CartState {
  final List<CartItem> items;
  final String modeLivraison; // 'retrait' ou 'livraison'
  final String? commune;
  final double fraisLivraison;

  CartState({
    this.items = const [],
    this.modeLivraison = 'retrait',
    this.commune,
    this.fraisLivraison = 0.0,
  });

  double get sousTotal => items.fold(0, (sum, item) => sum + item.sousTotal);
  double get total => sousTotal + fraisLivraison;
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantite);

  CartState copyWith({
    List<CartItem>? items,
    String? modeLivraison,
    String? commune,
    double? fraisLivraison,
  }) {
    return CartState(
      items: items ?? this.items,
      modeLivraison: modeLivraison ?? this.modeLivraison,
      commune: commune ?? this.commune,
      fraisLivraison: fraisLivraison ?? this.fraisLivraison,
    );
  }
}

class PanierNotifier extends StateNotifier<CartState> {
  PanierNotifier() : super(CartState());

  void ajouterArticle(CartItem newItem) {
    final existingIndex = state.items.indexWhere((item) =>
        item.productId == newItem.productId &&
        item.optionLabel == newItem.optionLabel);

    if (existingIndex >= 0) {
      // Mettre à jour la quantité si l'article existe déjà avec la même option
      final items = List<CartItem>.from(state.items);
      final existingItem = items[existingIndex];
      final newQuantity = existingItem.quantite + newItem.quantite;
      
      items[existingIndex] = existingItem.copyWith(
        quantite: newQuantity,
        sousTotal: newQuantity * existingItem.prixUnitaire,
      );
      state = state.copyWith(items: items);
    } else {
      // Ajouter le nouvel article
      state = state.copyWith(items: [...state.items, newItem]);
    }
  }

  void modifierQuantite(String productId, String optionLabel, int newQuantity) {
    if (newQuantity <= 0) {
      retirerArticle(productId, optionLabel);
      return;
    }

    final items = state.items.map((item) {
      if (item.productId == productId && item.optionLabel == optionLabel) {
        return item.copyWith(
          quantite: newQuantity,
          sousTotal: newQuantity * item.prixUnitaire,
        );
      }
      return item;
    }).toList();

    state = state.copyWith(items: items);
  }

  void retirerArticle(String productId, String optionLabel) {
    final items = state.items.where((item) => 
      !(item.productId == productId && item.optionLabel == optionLabel)
    ).toList();
    
    state = state.copyWith(items: items);
  }

  void setModeLivraison(String mode) {
    if (mode == 'retrait') {
      state = state.copyWith(modeLivraison: mode, fraisLivraison: 0.0, commune: null);
    } else {
      state = state.copyWith(modeLivraison: mode);
    }
  }

  void setCommune(String commune, double frais) {
    state = state.copyWith(commune: commune, fraisLivraison: frais);
  }

  void viderPanier() {
    state = CartState();
  }
}

final panierProvider = StateNotifierProvider<PanierNotifier, CartState>((ref) {
  return PanierNotifier();
});

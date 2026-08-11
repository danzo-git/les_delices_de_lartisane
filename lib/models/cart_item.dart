class CartItem {
  final String productId;
  final String nom;
  final String optionLabel;
  final double prixUnitaire;
  final int quantite;
  final double sousTotal;
  final String? imageUrl; // Utile pour l'affichage dans le panier

  CartItem({
    required this.productId,
    required this.nom,
    required this.optionLabel,
    required this.prixUnitaire,
    required this.quantite,
    required this.sousTotal,
    this.imageUrl,
  });

  CartItem copyWith({
    String? productId,
    String? nom,
    String? optionLabel,
    double? prixUnitaire,
    int? quantite,
    double? sousTotal,
    String? imageUrl,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      nom: nom ?? this.nom,
      optionLabel: optionLabel ?? this.optionLabel,
      prixUnitaire: prixUnitaire ?? this.prixUnitaire,
      quantite: quantite ?? this.quantite,
      sousTotal: sousTotal ?? this.sousTotal,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

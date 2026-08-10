import 'package:cloud_firestore/cloud_firestore.dart';

class ProductOption {
  final String label;
  final double prix;

  ProductOption({
    required this.label,
    required this.prix,
  });

  factory ProductOption.fromMap(Map<String, dynamic> map) {
    return ProductOption(
      label: map['label'] as String? ?? '',
      prix: (map['prix'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'prix': prix,
    };
  }
}

class Product {
  final String id;
  final String nom;
  final String description;
  final String categorieId;
  final String imageUrl;
  final bool disponible;
  final String ingredients;
  final String allergenes;
  final double noteMoyenne;
  final int nombreAvis;
  final List<ProductOption> options;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.nom,
    required this.description,
    required this.categorieId,
    required this.imageUrl,
    required this.disponible,
    required this.ingredients,
    required this.allergenes,
    required this.noteMoyenne,
    required this.nombreAvis,
    required this.options,
    this.createdAt,
  });

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      nom: map['nom'] as String? ?? '',
      description: map['description'] as String? ?? '',
      categorieId: map['categorie_id'] as String? ?? '',
      imageUrl: map['image_url'] as String? ?? '',
      disponible: map['disponible'] as bool? ?? true,
      ingredients: map['ingredients'] as String? ?? '',
      allergenes: map['allergenes'] as String? ?? '',
      noteMoyenne: (map['note_moyenne'] as num?)?.toDouble() ?? 0.0,
      nombreAvis: (map['nombre_avis'] as num?)?.toInt() ?? 0,
      options: (map['options'] as List<dynamic>?)
              ?.map((item) => ProductOption.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: map['created_at'] != null
          ? (map['created_at'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'description': description,
      'categorie_id': categorieId,
      'image_url': imageUrl,
      'disponible': disponible,
      'ingredients': ingredients,
      'allergenes': allergenes,
      'note_moyenne': noteMoyenne,
      'nombre_avis': nombreAvis,
      'options': options.map((o) => o.toMap()).toList(),
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }
}

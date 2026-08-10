import 'package:cloud_firestore/cloud_firestore.dart';

class ProductOption {
  final String label;
  final double prix;

  ProductOption({
    required this.label,
    required this.prix,
  });

  factory ProductOption.fromMap(Map<String, dynamic> map) {
    // Gestion du type au cas où l'utilisateur a saisi une String au lieu d'un Number dans Firestore
    double parsedPrix = 0.0;
    if (map['prix'] is num) {
      parsedPrix = (map['prix'] as num).toDouble();
    } else if (map['prix'] is String) {
      parsedPrix = double.tryParse(map['prix'] as String) ?? 0.0;
    }

    return ProductOption(
      label: map['label'] as String? ?? '',
      prix: parsedPrix,
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
    // Parsing robuste pour noteMoyenne
    double parsedNote = 0.0;
    if (map['note_moyenne'] is num) {
      parsedNote = (map['note_moyenne'] as num).toDouble();
    } else if (map['note_moyenne'] is String) {
      parsedNote = double.tryParse(map['note_moyenne'] as String) ?? 0.0;
    }

    // Parsing robuste pour nombreAvis
    int parsedAvis = 0;
    if (map['nombre_avis'] is num) {
      parsedAvis = (map['nombre_avis'] as num).toInt();
    } else if (map['nombre_avis'] is String) {
      parsedAvis = int.tryParse(map['nombre_avis'] as String) ?? 0;
    }

    // Parsing de disponible (au cas où entré comme string)
    bool parsedDisponible = true;
    if (map['disponible'] is bool) {
      parsedDisponible = map['disponible'] as bool;
    } else if (map['disponible'] is String) {
      parsedDisponible = (map['disponible'] as String).toLowerCase() == 'true';
    }

    return Product(
      id: id,
      nom: map['nom'] as String? ?? '',
      description: map['description'] as String? ?? '',
      categorieId: map['categorie_id'] as String? ?? '',
      imageUrl: map['image_url'] as String? ?? '',
      disponible: parsedDisponible,
      ingredients: map['ingredients'] as String? ?? '',
      allergenes: map['allergenes'] as String? ?? '',
      noteMoyenne: parsedNote,
      nombreAvis: parsedAvis,
      options: (map['options'] as List<dynamic>?)
              ?.map((item) => ProductOption.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: map['created_at'] != null && map['created_at'] is Timestamp
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

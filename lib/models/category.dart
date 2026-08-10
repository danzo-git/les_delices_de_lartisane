class Category {
  final String id;
  final String nom;
  final int ordre;
  final String? icone;

  Category({
    required this.id,
    required this.nom,
    required this.ordre,
    this.icone,
  });

  factory Category.fromMap(Map<String, dynamic> map, String id) {
    int parsedOrdre = 0;
    if (map['ordre'] is num) {
      parsedOrdre = (map['ordre'] as num).toInt();
    } else if (map['ordre'] is String) {
      parsedOrdre = int.tryParse(map['ordre'] as String) ?? 0;
    }

    return Category(
      id: id,
      nom: map['nom'] as String? ?? '',
      ordre: parsedOrdre,
      icone: map['icone'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'ordre': ordre,
      if (icone != null) 'icone': icone,
    };
  }
}

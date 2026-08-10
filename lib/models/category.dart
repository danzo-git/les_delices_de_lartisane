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
    return Category(
      id: id,
      nom: map['nom'] as String? ?? '',
      ordre: (map['ordre'] as num?)?.toInt() ?? 0,
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

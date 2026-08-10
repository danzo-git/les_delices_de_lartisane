import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String productId;
  final String nom;
  final String optionLabel;
  final double prixUnitaire;
  final int quantite;
  final double sousTotal;

  OrderItem({
    required this.productId,
    required this.nom,
    required this.optionLabel,
    required this.prixUnitaire,
    required this.quantite,
    required this.sousTotal,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['product_id'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      optionLabel: map['option_label'] as String? ?? '',
      prixUnitaire: (map['prix_unitaire'] as num?)?.toDouble() ?? 0.0,
      quantite: (map['quantite'] as num?)?.toInt() ?? 1,
      sousTotal: (map['sous_total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'nom': nom,
      'option_label': optionLabel,
      'prix_unitaire': prixUnitaire,
      'quantite': quantite,
      'sous_total': sousTotal,
    };
  }
}

class OrderStatusHistory {
  final String statut;
  final DateTime? date;

  OrderStatusHistory({
    required this.statut,
    this.date,
  });

  factory OrderStatusHistory.fromMap(Map<String, dynamic> map) {
    return OrderStatusHistory(
      statut: map['statut'] as String? ?? '',
      date: map['date'] != null ? (map['date'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'statut': statut,
      'date': date != null ? Timestamp.fromDate(date!) : null,
    };
  }
}

class OrderModel {
  final String id;
  final String numero;
  final String userId;
  final String clientNom;
  final String clientTelephone;
  final List<OrderItem> items;
  final double sousTotal;
  final String modeLivraison; // "retrait" | "livraison"
  final String? commune;
  final double fraisLivraison;
  final double total;
  final String modePaiement; // "wave" | "orange_money" | "mtn_momo"
  final String statutPaiement; // "en_attente" | "confirme" | "echoue"
  final String statutCommande; // "recue" | "en_preparation" | "prete" | "livree"
  final List<OrderStatusHistory> historiqueStatuts;
  final DateTime? createdAt;

  OrderModel({
    required this.id,
    required this.numero,
    required this.userId,
    required this.clientNom,
    required this.clientTelephone,
    required this.items,
    required this.sousTotal,
    required this.modeLivraison,
    this.commune,
    required this.fraisLivraison,
    required this.total,
    required this.modePaiement,
    required this.statutPaiement,
    required this.statutCommande,
    required this.historiqueStatuts,
    this.createdAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id,
      numero: map['numero'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      clientNom: map['client_nom'] as String? ?? '',
      clientTelephone: map['client_telephone'] as String? ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      sousTotal: (map['sous_total'] as num?)?.toDouble() ?? 0.0,
      modeLivraison: map['mode_livraison'] as String? ?? 'retrait',
      commune: map['commune'] as String?,
      fraisLivraison: (map['frais_livraison'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      modePaiement: map['mode_paiement'] as String? ?? 'wave',
      statutPaiement: map['statut_paiement'] as String? ?? 'en_attente',
      statutCommande: map['statut_commande'] as String? ?? 'recue',
      historiqueStatuts: (map['historique_statuts'] as List<dynamic>?)
              ?.map((item) => OrderStatusHistory.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: map['created_at'] != null
          ? (map['created_at'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'numero': numero,
      'user_id': userId,
      'client_nom': clientNom,
      'client_telephone': clientTelephone,
      'items': items.map((i) => i.toMap()).toList(),
      'sous_total': sousTotal,
      'mode_livraison': modeLivraison,
      if (commune != null) 'commune': commune,
      'frais_livraison': fraisLivraison,
      'total': total,
      'mode_paiement': modePaiement,
      'statut_paiement': statutPaiement,
      'statut_commande': statutCommande,
      'historique_statuts': historiqueStatuts.map((h) => h.toMap()).toList(),
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }
}

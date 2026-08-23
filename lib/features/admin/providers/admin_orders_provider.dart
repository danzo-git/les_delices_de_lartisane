import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/order.dart';

/// Filtre de statut sélectionné par l'admin
/// Valeur vide = "Toutes"
final adminOrderStatusFilterProvider = StateProvider<String>((ref) => '');

/// Stream de toutes les commandes, avec filtre optionnel par statut
final adminOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final statusFilter = ref.watch(adminOrderStatusFilterProvider);

  Query<Map<String, dynamic>> query = FirebaseFirestore.instance
      .collection('orders')
      .orderBy('created_at', descending: true);

  if (statusFilter.isNotEmpty) {
    query = query.where('statut_commande', isEqualTo: statusFilter);
  }

  return query.snapshots().map((snapshot) {
    return snapshot.docs
        .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
        .toList();
  });
});

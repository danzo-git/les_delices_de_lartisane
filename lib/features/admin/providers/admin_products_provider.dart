import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/product.dart';

final adminProductsProvider = StreamProvider<List<Product>>((ref) {
  final firestore = FirebaseFirestore.instance;
  
  // On récupère tous les produits sans filtre sur 'disponible'
  // et on les trie par ordre alphabétique du nom
  return firestore
      .collection('products')
      .orderBy('nom')
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => Product.fromMap(doc.data(), doc.id))
        .toList();
  });
});

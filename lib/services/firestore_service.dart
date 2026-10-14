import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/delivery_fee.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- CATÉGORIES ---
  Future<List<Category>> getCategories() async {
    try {
      final snapshot = await _firestore
          .collection('categories')
          .orderBy('ordre')
          .get();

      return snapshot.docs
          .map((doc) => Category.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des catégories: $e');
      return [];
    }
  }

  // --- PRODUITS ---
  Future<List<Product>> getProducts({String? categoryId}) async {
    try {
      Query query = _firestore
          .collection('products')
          .where('disponible', isEqualTo: true);

      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.where('categorie_id', isEqualTo: categoryId);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => Product.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des produits: $e');
      return [];
    }
  }

  Future<Product?> getProduct(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();

      if (doc.exists && doc.data() != null) {
        return Product.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération du produit: $e');
      return null;
    }
  }

  Future<void> createProduct(Product product) async {
    try {
      await _firestore.collection('products').doc(product.id).set(product.toMap());
    } catch (e) {
      print('Erreur lors de la création du produit: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('products').doc(productId).update(data);
    } catch (e) {
      print('Erreur lors de la mise à jour du produit: $e');
      rethrow;
    }
  }

  Future<void> toggleProductAvailability(String productId, bool disponible) async {
    try {
      await _firestore.collection('products').doc(productId).update({'disponible': disponible});
    } catch (e) {
      print('Erreur lors de la mise à jour de la disponibilité: $e');
      rethrow;
    }
  }

  // --- COMMANDES ---
  Future<OrderModel?> getOrder(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (doc.exists && doc.data() != null) {
        return OrderModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération de la commande: $e');
      return null;
    }
  }

  Stream<OrderModel?> streamOrder(String orderId) {
    return _firestore.collection('orders').doc(orderId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return OrderModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  Stream<List<OrderModel>> getUserOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> cancelOrder(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (!doc.exists) return;
      
      final currentOrder = OrderModel.fromMap(doc.data()!, doc.id);
      if (currentOrder.statutCommande != 'en_attente_validation') {
        throw Exception('Impossible d\'annuler une commande déjà traitée.');
      }

      final newHistoryEntry = OrderStatusHistory(
        statut: 'annulee',
        date: DateTime.now(),
      ).toMap();

      await _firestore.collection('orders').doc(orderId).update({
        'statut_commande': 'annulee',
        'historique_statuts': FieldValue.arrayUnion([newHistoryEntry]),
      });
    } catch (e) {
      print('Erreur lors de l\'annulation de la commande: $e');
      rethrow;
    }
  }

  // --- FRAIS DE LIVRAISON ---
  Future<List<DeliveryFee>> getDeliveryFees() async {
    try {
      final snapshot = await _firestore
          .collection('delivery_fees')
          .where('actif', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) => DeliveryFee.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des frais de livraison: $e');
      return [];
    }
  }

  // --- FAVORIS ---
  Stream<bool> isFavori(String userId, String productId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favoris')
        .doc(productId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> toggleFavori(String userId, String productId) async {
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('favoris')
        .doc(productId);
    
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.delete();
    } else {
      await docRef.set({
        'product_id': productId,
        'added_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<List<String>> getFavorisIds(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favoris')
        .orderBy('added_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }
}

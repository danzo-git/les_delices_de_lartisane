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
}

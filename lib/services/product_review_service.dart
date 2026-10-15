import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ProductReviewService {
  ProductReviewService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchReviews(String productId) {
    return _firestore
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Future<void> submitReview({
    required String orderId,
    required String productId,
    required int note,
    required String commentaire,
  }) async {
    final callable = _functions.httpsCallable('submitVerifiedProductReview');
    await callable.call({
      'order_id': orderId,
      'product_id': productId,
      'note': note,
      'commentaire': commentaire,
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class ProductReview {
  const ProductReview({
    required this.note,
    required this.commentaire,
    required this.verifiedPurchase,
    required this.createdAt,
  });

  final int note;
  final String commentaire;
  final bool verifiedPurchase;
  final DateTime? createdAt;

  factory ProductReview.fromMap(Map<String, dynamic> map) {
    final createdAt = map['created_at'];
    return ProductReview(
      note: (map['note'] as num?)?.toInt() ?? 0,
      commentaire: map['commentaire'] as String? ?? '',
      verifiedPurchase: map['verified_purchase'] as bool? ?? false,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}

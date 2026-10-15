import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/product_review.dart';
import '../../../services/product_review_service.dart';

class ProductReviewsScreen extends StatelessWidget {
  const ProductReviewsScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) {
    final reviews = ProductReviewService().watchReviews(productId);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F0),
      appBar: AppBar(
        title: const Text('Avis clients'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder(
        stream: reviews,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Impossible de charger les avis.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data!.docs;
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aucun avis pour le moment. Après ta commande, tu pourras partager ton expérience.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final review = ProductReview.fromMap(entries[index].data());
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (star) => Icon(
                            star < review.note
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: Colors.amber.shade700,
                            size: 20,
                          ),
                        ),
                        const Spacer(),
                        if (review.createdAt != null)
                          Text(
                            DateFormat(
                              'dd MMM yyyy',
                              'fr_FR',
                            ).format(review.createdAt!),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    if (review.commentaire.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(review.commentaire),
                    ],
                    if (review.verifiedPurchase) ...[
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: Color(0xFF3C8371),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Achat vérifié',
                            style: TextStyle(
                              color: Color(0xFF3C8371),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

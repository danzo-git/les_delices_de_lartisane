import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/order.dart';
import '../../../services/product_review_service.dart';
import '../providers/order_provider.dart';

class OrderReviewScreen extends ConsumerWidget {
  const OrderReviewScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderStreamProvider(orderId));
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F0),
      appBar: AppBar(
        title: const Text('Ton avis'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Commande indisponible.')),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Commande indisponible.'));
          }
          if (order.statutCommande != 'livree') {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Tu pourras évaluer les produits après la livraison de ta commande.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final products = <String, OrderItem>{};
          for (final item in order.items) {
            if (item.productId.isNotEmpty) {
              products.putIfAbsent(item.productId, () => item);
            }
          }
          if (products.isEmpty) {
            return const Center(child: Text('Aucun produit à évaluer.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Comment s’est passée ta commande ?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text('Tes avis aident les autres clients à choisir.'),
              const SizedBox(height: 16),
              for (final entry in products.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReviewProductCard(
                    order: order,
                    productId: entry.key,
                    productName: entry.value.nom,
                    alreadyReviewed: order.reviewedProductIds.contains(
                      entry.key,
                    ),
                    onSubmitted: () =>
                        ref.invalidate(orderStreamProvider(orderId)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewProductCard extends ConsumerStatefulWidget {
  const _ReviewProductCard({
    required this.order,
    required this.productId,
    required this.productName,
    required this.alreadyReviewed,
    required this.onSubmitted,
  });

  final OrderModel order;
  final String productId;
  final String productName;
  final bool alreadyReviewed;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<_ReviewProductCard> createState() => _ReviewProductCardState();
}

class _ReviewProductCardState extends ConsumerState<_ReviewProductCard> {
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choisis une note avant d’envoyer ton avis.'),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ProductReviewService().submitReview(
        orderId: widget.order.id,
        productId: widget.productId,
        note: _rating,
        commentaire: _commentController.text,
      );
      if (!mounted) return;
      widget.onSubmitted();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci, ton avis a été envoyé.')),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Impossible d’envoyer ton avis.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’envoyer ton avis. Réessaie.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alreadyReviewed = widget.alreadyReviewed;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.productName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (alreadyReviewed) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF3C8371), size: 18),
                SizedBox(width: 8),
                Text('Avis envoyé', style: TextStyle(color: Color(0xFF3C8371))),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                5,
                (index) => IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() => _rating = index + 1),
                  icon: Icon(
                    index < _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber.shade700,
                    size: 30,
                  ),
                ),
              ),
            ),
            TextField(
              controller: _commentController,
              enabled: !_isSubmitting,
              maxLength: 800,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Un commentaire (facultatif)',
                border: OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Envoyer mon avis'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

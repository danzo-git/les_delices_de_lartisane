import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/order_provider.dart';
import '../../../models/order.dart';

class OrderTrackingScreen extends ConsumerWidget {
  final String orderId;

  const OrderTrackingScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderStream = ref.watch(orderStreamProvider(orderId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Suivi de commande',
          style: TextStyle(
            color: Color(0xFF2C2C2C),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF2C2C2C)),
      ),
      body: orderStream.when(
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Commande introuvable'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(order),
                const SizedBox(height: 24),
                _buildTimeline(order),
                const SizedBox(height: 24),
                _buildRecap(order),
                const SizedBox(height: 24),
                _buildPaymentMethod(order),
                const SizedBox(height: 32),
                _buildContactButton(context),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFE96A92))),
        error: (err, stack) => Center(child: Text('Erreur: $err')),
      ),
    );
  }

  Widget _buildHeader(OrderModel order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Commande #${order.numero}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C2C2C),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Passée le ${order.createdAt != null ? DateFormat('dd MMM yyyy à HH:mm', 'fr_FR').format(order.createdAt!) : ''}',
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(OrderModel order) {
    final steps = [
      _TimelineStepData('Commande reçue', 'recue', _isStepCompleted(order, 'recue')),
      _TimelineStepData('Paiement confirmé', 'paiement_confirme', order.statutPaiement == 'confirme'),
      _TimelineStepData('En préparation', 'en_preparation', _isStepCompleted(order, 'en_preparation')),
      _TimelineStepData('Prête', 'prete', _isStepCompleted(order, 'prete')),
      _TimelineStepData('Livrée', 'livree', _isStepCompleted(order, 'livree')),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isLast = index == steps.length - 1;

          // Find date in history
          DateTime? stepDate;
          if (step.isCompleted) {
            // For payment confirmed, we might not have a specific history entry, fallback to created at or check history
            final historyMatch = order.historiqueStatuts.where((h) => h.statut == step.statusKey).toList();
            if (historyMatch.isNotEmpty) {
              stepDate = historyMatch.last.date;
            } else if (step.statusKey == 'recue') {
              stepDate = order.createdAt;
            }
          }

          return _TimelineRow(
            title: step.title,
            isCompleted: step.isCompleted,
            isLast: isLast,
            date: stepDate,
          );
        }).toList(),
      ),
    );
  }

  bool _isStepCompleted(OrderModel order, String status) {
    final statuses = ['recue', 'en_preparation', 'prete', 'livree'];
    final currentIndex = statuses.indexOf(order.statutCommande);
    final targetIndex = statuses.indexOf(status);
    return currentIndex >= targetIndex;
  }

  Widget _buildRecap(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Récapitulatif',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C2C2C),
            ),
          ),
          const SizedBox(height: 16),
          _buildRecapRow('Sous-total', order.sousTotal),
          const SizedBox(height: 8),
          _buildRecapRow('Livraison', order.fraisLivraison),
          const Divider(height: 24, thickness: 1, color: Color(0xFFF7F9F0)),
          _buildRecapRow('Total', order.total, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildRecapRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? const Color(0xFF2C2C2C) : const Color(0xFF8E8E93),
          ),
        ),
        Text(
          '${amount.toInt()} FCFA',
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: const Color(0xFF2C2C2C),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethod(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mode de paiement',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C2C2C),
            ),
          ),
          const SizedBox(height: 16),
          _PaymentMethodTile(
            logoPath: 'assets/images/wave_logo.png', // Assuming asset path
            name: 'Wave',
            isSelected: order.modePaiement == 'wave',
          ),
          const SizedBox(height: 8),
          _PaymentMethodTile(
            logoPath: 'assets/images/om_logo.png',
            name: 'Orange Money',
            isSelected: order.modePaiement == 'orange_money',
          ),
          const SizedBox(height: 8),
          _PaymentMethodTile(
            logoPath: 'assets/images/momo_logo.png',
            name: 'MTN MoMo',
            isSelected: order.modePaiement == 'mtn_momo',
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        // Logique pour WhatsApp, réutilise celle du paiement
      },
      icon: const Icon(Icons.support_agent, color: Color(0xFF3C8371)),
      label: const Text(
        'Besoin d\'aide ? Contactez-nous',
        style: TextStyle(color: Color(0xFF3C8371)),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: const BorderSide(color: Color(0xFF3C8371)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _TimelineStepData {
  final String title;
  final String statusKey;
  final bool isCompleted;

  _TimelineStepData(this.title, this.statusKey, this.isCompleted);
}

class _TimelineRow extends StatelessWidget {
  final String title;
  final bool isCompleted;
  final bool isLast;
  final DateTime? date;

  const _TimelineRow({
    required this.title,
    required this.isCompleted,
    required this.isLast,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? const Color(0xFF3C8371) : const Color(0xFFE0E0E0),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? const Color(0xFF3C8371) : const Color(0xFFE0E0E0),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
                  color: isCompleted ? const Color(0xFF2C2C2C) : const Color(0xFF8E8E93),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isCompleted
                    ? (date != null ? DateFormat('dd MMM yyyy à HH:mm', 'fr_FR').format(date!) : 'Terminé')
                    : 'En attente',
                style: TextStyle(
                  fontSize: 12,
                  color: isCompleted ? const Color(0xFF8E8E93) : const Color(0xFFBDBDBD),
                ),
              ),
              if (!isLast) const SizedBox(height: 24), // Match the line height
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final String logoPath;
  final String name;
  final bool isSelected;

  const _PaymentMethodTile({
    required this.logoPath,
    required this.name,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF7F9F0) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF3C8371) : const Color(0xFFF0F0F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            // Placeholder for logo if image doesn't exist, use text or icon
            child: const Center(child: Icon(Icons.payment, size: 20, color: Color(0xFF8E8E93))),
          ),
          const SizedBox(width: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2C2C2C),
            ),
          ),
          const Spacer(),
          if (isSelected)
            const Icon(Icons.radio_button_checked, color: Color(0xFFE96A92), size: 20)
          else
            const Icon(Icons.radio_button_off, color: Color(0xFFE0E0E0), size: 20),
        ],
      ),
    );
  }
}

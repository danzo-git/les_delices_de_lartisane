import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/order_provider.dart';
import '../../../models/order.dart';
import '../../../services/payment_service.dart';
import '../../../theme/app_colors.dart';

final paymentServiceProvider = Provider((ref) => PaymentService());

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderTrackingScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  bool _isPaying = false;

  Future<void> _processPayment(OrderModel order) async {
    setState(() => _isPaying = true);
    try {
      final paymentService = ref.read(paymentServiceProvider);
      final checkoutUrl = await paymentService.initierPaiement(order.id);

      if (checkoutUrl != null) {
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showErrorSnackBar("Impossible d'ouvrir le lien de paiement.");
        }
      } else {
        _showErrorSnackBar("Erreur: Lien de paiement non reçu.");
      }
    } catch (e) {
      _showErrorSnackBar("Erreur lors du paiement: $e");
    } finally {
      if (mounted) {
        setState(() => _isPaying = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderStream = ref.watch(orderStreamProvider(widget.orderId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Suivi de commande',
          style: TextStyle(color: Color(0xFF2C2C2C), fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF2C2C2C)),
      ),
      body: orderStream.when(
        data: (order) {
          if (order == null) return const Center(child: Text('Commande introuvable'));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(order),
                const SizedBox(height: 24),
                
                if (order.statutCommande == 'refusee')
                  _buildRefusalCard(order)
                else if (order.statutCommande == 'acceptee' && order.statutPaiement != 'confirme')
                  _buildPaymentPrompt(order)
                else ...[
                  _buildTimeline(order),
                  const SizedBox(height: 24),
                ],

                _buildRecap(order),
                
                // On cache le mode de paiement tant que la commande n'est pas acceptée/payée
                if (order.statutCommande != 'en_attente_validation' && order.statutCommande != 'refusee') ...[
                  const SizedBox(height: 24),
                  _buildPaymentMethod(order),
                ],
                
                const SizedBox(height: 32),
                _buildContactButton(context),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaire)),
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
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
        ),
        const SizedBox(height: 4),
        Text(
          'Passée le ${order.createdAt != null ? DateFormat('dd MMM yyyy à HH:mm', 'fr_FR').format(order.createdAt!) : ''}',
          style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildRefusalCard(OrderModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Text(
                'Commande non validée',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            order.motifRefus ?? "L'artisane n'a pas pu valider votre commande pour le créneau demandé.",
            style: TextStyle(color: Colors.orange.shade900),
          ),
          const SizedBox(height: 16),
          const Text(
            "N'hésitez pas à nous contacter pour trouver un autre arrangement.",
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentPrompt(OrderModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: AppColors.primaire.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: AppColors.primaire, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Commande validée !',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.texte),
          ),
          const SizedBox(height: 8),
          const Text(
            "L'artisane a confirmé la disponibilité. Vous pouvez maintenant procéder au paiement pour finaliser votre commande.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaire),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isPaying ? null : () => _processPayment(order),
              child: _isPaying
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Payer maintenant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(OrderModel order) {
    final bool estEnAttenteValidation = order.statutCommande == 'en_attente_validation';
    
    // Si on est encore en attente de validation, on affiche une timeline courte
    if (estEnAttenteValidation) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
             _TimelineRow(
              title: "Commande envoyée",
              isCompleted: true,
              isLast: false,
              date: order.createdAt,
            ),
            const _TimelineRow(
              title: "En attente de validation par l'artisane",
              isCompleted: false,
              isLast: true,
              date: null,
            ),
          ],
        ),
      );
    }

    // Sinon, timeline classique post-validation
    final steps = [
      _TimelineStepData('Commande validée', 'acceptee', true), // Toujours vrai si on arrive ici
      _TimelineStepData('Paiement confirmé', 'paiement_confirme', order.statutPaiement == 'confirme'),
      _TimelineStepData('En préparation', 'en_preparation', _isStepCompleted(order, 'en_preparation')),
      _TimelineStepData('Prête', 'prete', _isStepCompleted(order, 'prete')),
      _TimelineStepData('Livrée', 'livree', _isStepCompleted(order, 'livree')),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isLast = index == steps.length - 1;

          DateTime? stepDate;
          if (step.isCompleted) {
            final historyMatch = order.historiqueStatuts.where((h) => h.statut == step.statusKey).toList();
            if (historyMatch.isNotEmpty) {
              stepDate = historyMatch.last.date;
            } else if (step.statusKey == 'acceptee') {
              stepDate = order.createdAt; // Approximation si non trouvée
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
    final statuses = ['en_attente_validation', 'acceptee', 'recue', 'en_preparation', 'prete', 'livree'];
    final currentIndex = statuses.indexOf(order.statutCommande);
    final targetIndex = statuses.indexOf(status);
    return currentIndex >= targetIndex && currentIndex != -1;
  }

  Widget _buildRecap(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Récapitulatif', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2C2C2C))),
          const SizedBox(height: 16),
          
          if (order.dateSouhaitee != null) ...[
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.primaire),
                const SizedBox(width: 8),
                Text(
                  'Date souhaitée: ${DateFormat('dd/MM/yyyy HH:mm').format(order.dateSouhaitee!)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          
          if (order.adresseLivraison != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 16, color: AppColors.primaire),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${order.commune ?? ''}\n${order.adresseLivraison!}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mode de paiement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2C2C2C))),
          const SizedBox(height: 16),
          _PaymentMethodTile(
            logoPath: 'assets/images/wave_logo.png',
            name: 'Wave',
            isSelected: order.modePaiement == 'wave',
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final Uri whatsappUrl = Uri.parse('https://wa.me/2250000000000?text=Bonjour,%20j\'ai%20besoin%20d\'aide%20pour%20ma%20commande.');
        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        }
      },
      icon: const Icon(Icons.support_agent, color: AppColors.primaire),
      label: const Text('Besoin d\'aide ? Contactez-nous', style: TextStyle(color: AppColors.primaire)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: const BorderSide(color: AppColors.primaire),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                color: isCompleted ? AppColors.primaire : const Color(0xFFE0E0E0),
              ),
              child: isCompleted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? AppColors.primaire : const Color(0xFFE0E0E0),
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
              if (!isLast) const SizedBox(height: 24),
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
          color: isSelected ? AppColors.primaire : const Color(0xFFF0F0F0),
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
            child: const Center(child: Icon(Icons.payment, size: 20, color: Color(0xFF8E8E93))),
          ),
          const SizedBox(width: 12),
          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF2C2C2C))),
          const Spacer(),
          if (isSelected)
            const Icon(Icons.radio_button_checked, color: AppColors.primaire, size: 20)
          else
            const Icon(Icons.radio_button_off, color: Color(0xFFE0E0E0), size: 20),
        ],
      ),
    );
  }
}

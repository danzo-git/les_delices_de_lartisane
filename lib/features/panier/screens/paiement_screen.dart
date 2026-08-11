import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/panier_provider.dart';
import '../../../services/payment_service.dart';
import '../../../models/order.dart';

final paymentServiceProvider = Provider((ref) => PaymentService());

class PaiementScreen extends ConsumerStatefulWidget {
  const PaiementScreen({super.key});

  @override
  ConsumerState<PaiementScreen> createState() => _PaiementScreenState();
}

class _PaiementScreenState extends ConsumerState<PaiementScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  String _generateOrderNumber() {
    final random = Random();
    final number = random.nextInt(9000) + 1000;
    return 'CMD-$number';
  }

  Future<void> _processPayment() async {
    final cartState = ref.read(panierProvider);
    final authState = ref.read(authProvider);

    if (authState.profile == null || authState.user == null) {
      setState(() => _errorMessage = 'Veuillez vous reconnecter.');
      return;
    }
    
    if (cartState.items.isEmpty) {
      setState(() => _errorMessage = 'Votre panier est vide.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final docRef = firestore.collection('orders').doc();
      final orderId = docRef.id;
      final orderNumber = _generateOrderNumber();

      final orderItems = cartState.items.map((item) => OrderItem(
        productId: item.productId,
        nom: item.nom,
        optionLabel: item.optionLabel,
        prixUnitaire: item.prixUnitaire,
        quantite: item.quantite,
        sousTotal: item.sousTotal,
      )).toList();

      final order = OrderModel(
        id: orderId,
        numero: orderNumber,
        userId: authState.user!.uid,
        clientNom: authState.profile!.nom,
        clientTelephone: authState.profile!.telephone,
        items: orderItems,
        sousTotal: cartState.sousTotal,
        modeLivraison: cartState.modeLivraison,
        commune: cartState.commune,
        fraisLivraison: cartState.fraisLivraison,
        total: cartState.total,
        modePaiement: 'wave', // ou le paiement choisi, l'API s'en charge aussi
        statutPaiement: 'en_attente',
        statutCommande: 'recue',
        historiqueStatuts: [
          OrderStatusHistory(statut: 'recue', date: DateTime.now())
        ],
        createdAt: DateTime.now(),
      );

      // 1. Sauvegarder la commande
      await docRef.set(order.toMap());

      // 2. Initier le paiement via GeniusPay
      final paymentService = ref.read(paymentServiceProvider);
      final checkoutUrl = await paymentService.initierPaiement(orderId);

      if (checkoutUrl != null) {
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        
        // 3. Vider le panier
        ref.read(panierProvider.notifier).viderPanier();
        
        // 4. Rediriger vers le suivi de commande
        if (mounted) {
          context.go('/order/$orderId');
        }
      } else {
        throw Exception('Impossible d\'obtenir le lien de paiement.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du paiement: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _contactSupport() async {
    final Uri whatsappUrl = Uri.parse('https://wa.me/2250000000000?text=Bonjour,%20j\'ai%20besoin%20d\'aide%20pour%20mon%20paiement.');
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(panierProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.texte,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Récapitulatif de la commande',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sous-total', style: TextStyle(color: AppColors.secondaire)),
                      Text('${cartState.sousTotal.toInt()} FCFA', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Frais de livraison', style: TextStyle(color: AppColors.secondaire)),
                      Text('${cartState.fraisLivraison.toInt()} FCFA', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total à payer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${cartState.total.toInt()} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaire)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            const Text(
              'Informations client',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.fond,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(authState.profile?.nom ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(authState.profile?.telephone ?? '', style: const TextStyle(color: AppColors.secondaire)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Payer via GeniusPay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _contactSupport,
                icon: const Icon(Icons.help_outline, color: AppColors.secondaire),
                label: const Text('Besoin d\'aide ? Contactez-nous', style: TextStyle(color: AppColors.texte)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

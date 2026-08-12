import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../providers/panier_provider.dart';
import '../providers/delivery_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../models/order.dart';
import '../../../services/firestore_service.dart';

final firestoreServiceProvider = Provider((ref) => FirestoreService());

class PanierScreen extends ConsumerStatefulWidget {
  const PanierScreen({super.key});

  @override
  ConsumerState<PanierScreen> createState() => _PanierScreenState();
}

class _PanierScreenState extends ConsumerState<PanierScreen> {
  final TextEditingController _adresseController = TextEditingController();
  DateTime? _dateSouhaitee;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _adresseController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaire,
              onPrimary: Colors.white,
              onSurface: AppColors.texte,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 0),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primaire,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _dateSouhaitee = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  String _generateOrderNumber() {
    final random = Random();
    final number = random.nextInt(9000) + 1000;
    return 'CMD-$number';
  }

  Future<void> _commander() async {
    final cartState = ref.read(panierProvider);
    final authState = ref.read(authProvider);

    if (authState.profile == null || authState.user == null) {
      setState(() => _errorMessage = 'Veuillez vous reconnecter.');
      return;
    }

    if (cartState.modeLivraison == 'livraison') {
      if (cartState.commune == null) {
        setState(() => _errorMessage = 'Veuillez sélectionner une commune.');
        return;
      }
      if (_adresseController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Veuillez entrer une adresse précise.');
        return;
      }
    }

    if (_dateSouhaitee == null) {
      setState(() => _errorMessage = 'Veuillez sélectionner une date et heure souhaitée.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final docRef = FirebaseFirestore.instance.collection('orders').doc();
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
        adresseLivraison: cartState.modeLivraison == 'livraison' ? _adresseController.text.trim() : null,
        dateSouhaitee: _dateSouhaitee,
        fraisLivraison: cartState.fraisLivraison,
        total: cartState.total,
        modePaiement: 'wave', // Par défaut pour l'instant
        statutPaiement: 'non_requis',
        statutCommande: 'en_attente_validation',
        historiqueStatuts: [
          OrderStatusHistory(statut: 'en_attente_validation', date: DateTime.now())
        ],
        createdAt: DateTime.now(),
      );

      await firestoreService.createOrder(order);

      ref.read(panierProvider.notifier).viderPanier();

      if (mounted) {
        context.go('/order/$orderId');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la création de la commande: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(panierProvider);
    final deliveryFeesAsync = ref.watch(deliveryFeesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon panier', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.texte,
      ),
      body: cartState.items.isEmpty
          ? const Center(child: Text('Votre panier est vide.', style: TextStyle(color: AppColors.secondaire)))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Liste des articles
                      ...cartState.items.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: item.imageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: item.imageUrl!,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) => _buildPlaceholder(),
                                      )
                                    : _buildPlaceholder(),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(item.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        ),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.close, color: AppColors.secondaire, size: 20),
                                          onPressed: () => ref.read(panierProvider.notifier).retirerArticle(item.productId, item.optionLabel),
                                        ),
                                      ],
                                    ),
                                    Text(item.optionLabel, style: const TextStyle(color: AppColors.secondaire, fontSize: 12)),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${item.prixUnitaire.toInt()} FCFA', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.fond,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove, size: 16, color: AppColors.primaire),
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                constraints: const BoxConstraints(),
                                                onPressed: () => ref.read(panierProvider.notifier).modifierQuantite(item.productId, item.optionLabel, item.quantite - 1),
                                              ),
                                              Text('${item.quantite}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                              IconButton(
                                                icon: const Icon(Icons.add, size: 16, color: AppColors.primaire),
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                constraints: const BoxConstraints(),
                                                onPressed: () => ref.read(panierProvider.notifier).modifierQuantite(item.productId, item.optionLabel, item.quantite + 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      
                      const SizedBox(height: 8),
                      
                      // Sélection Date
                      const Text('Date et heure souhaitées', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => _selectDateTime(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: AppColors.primaire),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _dateSouhaitee != null 
                                      ? DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr_FR').format(_dateSouhaitee!)
                                      : 'Choisir une date et heure',
                                  style: TextStyle(
                                    color: _dateSouhaitee != null ? AppColors.texte : AppColors.secondaire,
                                    fontWeight: _dateSouhaitee != null ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Section Mode de retrait et Livraison
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Mode de retrait', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRetraitOption(
                              title: 'Retrait en boutique',
                              value: 'retrait',
                              groupValue: cartState.modeLivraison,
                              onChanged: (val) => ref.read(panierProvider.notifier).setModeLivraison(val!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildRetraitOption(
                              title: 'Livraison',
                              value: 'livraison',
                              groupValue: cartState.modeLivraison,
                              onChanged: (val) => ref.read(panierProvider.notifier).setModeLivraison(val!),
                            ),
                          ),
                        ],
                      ),
                      
                      if (cartState.modeLivraison == 'livraison') ...[
                        const SizedBox(height: 16),
                        const Text('Commune de livraison', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        deliveryFeesAsync.when(
                          data: (fees) {
                            if (fees.isEmpty) return const Text('Aucune commune disponible');
                            return DropdownButtonFormField<String>(
                              value: cartState.commune,
                              hint: const Text('Sélectionnez une commune'),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              items: fees.map((fee) {
                                return DropdownMenuItem(
                                  value: fee.commune,
                                  child: Text('${fee.commune} (${fee.frais.toInt()} FCFA)'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  final selectedFee = fees.firstWhere((f) => f.commune == val);
                                  ref.read(panierProvider.notifier).setCommune(val, selectedFee.frais);
                                }
                              },
                            );
                          },
                          loading: () => const CircularProgressIndicator(),
                          error: (e, st) => Text('Erreur: $e'),
                        ),
                        
                        const SizedBox(height: 16),
                        const Text('Adresse précise', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _adresseController,
                          decoration: InputDecoration(
                            hintText: 'Rue, quartier, repère...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          maxLines: 2,
                        ),
                      ],

                      const SizedBox(height: 24),
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
                          Text(cartState.fraisLivraison > 0 ? '${cartState.fraisLivraison.toInt()} FCFA' : 'Gratuit', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text('${cartState.total.toInt()} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primaire)),
                        ],
                      ),
                      
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                        ),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _commander,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Commander', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: AppColors.fond,
      child: const Icon(Icons.cake, color: AppColors.primaire),
    );
  }

  Widget _buildRetraitOption({
    required String title,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.fond : Colors.white,
          border: Border.all(color: isSelected ? AppColors.primaire : Colors.grey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primaire : Colors.grey,
              size: 20,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.primaire : AppColors.texte,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

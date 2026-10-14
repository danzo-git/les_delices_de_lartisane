import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../models/delivery_schedule.dart';
import '../../../models/order.dart';
import '../../../services/delivery_schedule_service.dart';
import '../../../theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/delivery_provider.dart';
import '../providers/panier_provider.dart';

class PanierScreen extends ConsumerStatefulWidget {
  const PanierScreen({super.key});

  @override
  ConsumerState<PanierScreen> createState() => _PanierScreenState();
}

class _PanierScreenState extends ConsumerState<PanierScreen> {
  final TextEditingController _adresseController = TextEditingController();
  final DeliveryScheduleService _deliveryScheduleService =
      DeliveryScheduleService();

  DateTime? _dateSouhaitee;
  AvailableDeliverySlot? _selectedDeliverySlot;
  bool _scheduleEnabled = false;
  bool _isLoadingAvailability = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _adresseController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // DATE + HEURE
  // ---------------------------------------------------------------------------

  Future<void> _selectDateTime(BuildContext context) async {
    if (_isLoadingAvailability) return;
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

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _isLoadingAvailability = true;
      _dateSouhaitee = null;
      _selectedDeliverySlot = null;
      _errorMessage = null;
    });

    try {
      final availability =
          await _deliveryScheduleService.getAvailability(pickedDate);
      if (!mounted) return;

      if (availability.enabled) {
        setState(() => _scheduleEnabled = true);
        if (availability.slots.isEmpty) {
          setState(() {
            _errorMessage = 'Aucun créneau disponible à cette date. Choisis un autre jour.';
          });
          return;
        }

        final selectedSlot = await showModalBottomSheet<AvailableDeliverySlot>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  'Choisis un créneau',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(
                    DateTime.utc(pickedDate.year, pickedDate.month, pickedDate.day),
                  ),
                  style: const TextStyle(color: AppColors.secondaire),
                ),
                const SizedBox(height: 12),
                for (final slot in availability.slots)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.schedule, color: AppColors.primaire),
                      title: Text(slot.timeLabel),
                      subtitle: Text(
                        '${slot.remainingCapacity} place${slot.remainingCapacity > 1 ? 's' : ''} restante${slot.remainingCapacity > 1 ? 's' : ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pop(slot),
                    ),
                  ),
              ],
            ),
          ),
        );
        if (!mounted || selectedSlot == null) return;
        setState(() {
          _selectedDeliverySlot = selectedSlot;
          _dateSouhaitee = selectedSlot.startAt;
        });
        return;
      }

      // Tant que l'artisane n'a pas activé le planning, on conserve le choix
      // libre déjà utilisé par l'application.
      setState(() => _scheduleEnabled = false);
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 0),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primaire),
          ),
          child: child!,
        ),
      );
      if (pickedTime == null || !mounted) return;
      setState(() {
        _dateSouhaitee = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Impossible de vérifier les disponibilités. Réessaie dans un instant.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingAvailability = false);
    }

  }

  // ---------------------------------------------------------------------------
  // NUMÉRO DE COMMANDE
  // ---------------------------------------------------------------------------

  String _generateOrderNumber() {
    final random = Random();
    final number = random.nextInt(9000) + 1000;

    return 'CMD-$number';
  }

  // ---------------------------------------------------------------------------
  // CRÉATION DE LA COMMANDE
  // ---------------------------------------------------------------------------

  Future<void> _commander() async {
    final cartState = ref.read(panierProvider);
    final authState = ref.read(authProvider);

    // Vérification utilisateur
    if (authState.profile == null || authState.user == null) {
      setState(() {
        _errorMessage = 'Veuillez vous reconnecter.';
      });

      return;
    }

    // Vérifications spécifiques à la livraison
    if (cartState.modeLivraison == 'livraison') {
      if (cartState.commune == null) {
        setState(() {
          _errorMessage = 'Veuillez sélectionner une commune.';
        });

        return;
      }

      if (_adresseController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Veuillez entrer une adresse précise.';
        });

        return;
      }
    }

    // Vérification date
    if (_dateSouhaitee == null) {
      setState(() {
        _errorMessage =
            'Veuillez sélectionner une date et heure souhaitée.';
      });

      return;
    }
    if (_scheduleEnabled && _selectedDeliverySlot == null) {
      setState(() {
        _errorMessage = 'Choisis un créneau encore disponible.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final docRef =
          FirebaseFirestore.instance.collection('orders').doc();

      final orderId = docRef.id;
      final orderNumber = _generateOrderNumber();

      final orderItems = cartState.items
          .map(
            (item) => OrderItem(
              productId: item.productId,
              nom: item.nom,
              optionLabel: item.optionLabel,
              prixUnitaire: item.prixUnitaire,
              quantite: item.quantite,
              sousTotal: item.sousTotal,
            ),
          )
          .toList();

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
        adresseLivraison: cartState.modeLivraison == 'livraison'
            ? _adresseController.text.trim()
            : null,
        dateSouhaitee: _dateSouhaitee,
        deliverySlotId: _selectedDeliverySlot?.id,
        deliverySlotDate: _selectedDeliverySlot?.dateKey,
        deliverySlotLabel: _selectedDeliverySlot?.timeLabel,
        fraisLivraison: cartState.fraisLivraison,
        total: cartState.total,
        modePaiement: 'wave',
        statutPaiement: 'non_requis',
        statutCommande: 'en_attente_validation',
        historiqueStatuts: [
          OrderStatusHistory(
            statut: 'en_attente_validation',
            date: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
      );

      final createdOrderId = await _deliveryScheduleService.createOrder(
        order,
        slot: _selectedDeliverySlot,
      );

      ref.read(panierProvider.notifier).viderPanier();

      if (mounted) {
        context.go('/order/$createdOrderId');
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message ?? 'Impossible de créer la commande.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Erreur lors de la création de la commande: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(panierProvider);
    final deliveryFeesAsync = ref.watch(deliveryFeesProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.fond,

      appBar: AppBar(
        title: const Text(
          'Mon panier',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.texte,
      ),

      body: cartState.items.isEmpty
          ? const Center(
              child: Text(
                'Votre panier est vide.',
                style: TextStyle(
                  color: AppColors.secondaire,
                ),
              ),
            )
          : SafeArea(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                children: [
                  // ----------------------------------------------------------------
                  // ARTICLES
                  // ----------------------------------------------------------------

                  ...cartState.items.map(
                    (item) {
                      return Container(
                        margin: const EdgeInsets.only(
                          bottom: 16,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            // IMAGE
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(8),
                              child: item.imageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl:
                                          item.imageUrl!,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorWidget:
                                          (
                                            context,
                                            url,
                                            error,
                                          ) =>
                                              _buildPlaceholder(),
                                    )
                                  : _buildPlaceholder(),
                            ),

                            const SizedBox(width: 16),

                            // INFORMATIONS ARTICLE
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.nom,
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(
                                        width: 8,
                                      ),

                                      IconButton(
                                        padding:
                                            EdgeInsets.zero,
                                        constraints:
                                            const BoxConstraints(),
                                        icon: const Icon(
                                          Icons.close,
                                          color: AppColors
                                              .secondaire,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          ref
                                              .read(
                                                panierProvider
                                                    .notifier,
                                              )
                                              .retirerArticle(
                                                item.productId,
                                                item.optionLabel,
                                              );
                                        },
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    item.optionLabel,
                                    style:
                                        const TextStyle(
                                      color:
                                          AppColors.secondaire,
                                      fontSize: 12,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.prixUnitaire.toInt()} FCFA',
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight.w600,
                                          ),
                                        ),
                                      ),

                                      Container(
                                        decoration:
                                            BoxDecoration(
                                          color:
                                              AppColors.fond,
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize:
                                              MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon:
                                                  const Icon(
                                                Icons.remove,
                                                size: 16,
                                                color: AppColors
                                                    .primaire,
                                              ),
                                              padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                horizontal: 8,
                                              ),
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () {
                                                ref
                                                    .read(
                                                      panierProvider
                                                          .notifier,
                                                    )
                                                    .modifierQuantite(
                                                      item.productId,
                                                      item.optionLabel,
                                                      item.quantite -
                                                          1,
                                                    );
                                              },
                                            ),

                                            Text(
                                              '${item.quantite}',
                                              style:
                                                  const TextStyle(
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                            ),

                                            IconButton(
                                              icon:
                                                  const Icon(
                                                Icons.add,
                                                size: 16,
                                                color: AppColors
                                                    .primaire,
                                              ),
                                              padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                horizontal: 8,
                                              ),
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () {
                                                ref
                                                    .read(
                                                      panierProvider
                                                          .notifier,
                                                    )
                                                    .modifierQuantite(
                                                      item.productId,
                                                      item.optionLabel,
                                                      item.quantite +
                                                          1,
                                                    );
                                              },
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
                    },
                  ),

                  const SizedBox(height: 8),

                  // ----------------------------------------------------------------
                  // DATE ET HEURE
                  // ----------------------------------------------------------------

                  Text(
                    _scheduleEnabled
                        ? 'Date et créneau souhaités'
                        : 'Date et heure souhaitées',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 12),

                  InkWell(
                    onTap: _isLoadingAvailability
                        ? null
                        : () => _selectDateTime(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color:
                              Colors.grey.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          _isLoadingAvailability
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaire,
                                  ),
                                )
                              : const Icon(
                                  Icons.calendar_today,
                                  color: AppColors.primaire,
                                ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              _selectedDeliverySlot != null
                                  ? '${_selectedDeliverySlot!.dateLabel} · ${_selectedDeliverySlot!.timeLabel}'
                                  : _dateSouhaitee != null
                                      ? DateFormat(
                                      'EEEE d MMMM yyyy à HH:mm',
                                      'fr_FR',
                                    ).format(
                                      _dateSouhaitee!,
                                    )
                                      : 'Choisir une date et heure',
                              style: TextStyle(
                                color:
                                    _dateSouhaitee != null
                                        ? AppColors.texte
                                        : AppColors
                                            .secondaire,
                                fontWeight:
                                    _dateSouhaitee != null
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                              ),
                            ),
                          ),

                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.secondaire,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ----------------------------------------------------------------
                  // LIVRAISON / RETRAIT
                  // ----------------------------------------------------------------

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.05,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Mode de retrait',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildRetraitOption(
                                title:
                                    'Retrait en boutique',
                                value: 'retrait',
                                groupValue:
                                    cartState
                                        .modeLivraison,
                                onChanged: (val) {
                                  if (val == null) {
                                    return;
                                  }

                                  ref
                                      .read(
                                        panierProvider
                                            .notifier,
                                      )
                                      .setModeLivraison(
                                        val,
                                      );
                                },
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: _buildRetraitOption(
                                title: 'Livraison',
                                value: 'livraison',
                                groupValue:
                                    cartState
                                        .modeLivraison,
                                onChanged: (val) {
                                  if (val == null) {
                                    return;
                                  }

                                  ref
                                      .read(
                                        panierProvider
                                            .notifier,
                                      )
                                      .setModeLivraison(
                                        val,
                                      );
                                },
                              ),
                            ),
                          ],
                        ),

                        // ------------------------------------------------------------
                        // INFORMATIONS LIVRAISON
                        // ------------------------------------------------------------

                        if (cartState.modeLivraison ==
                            'livraison') ...[
                          const SizedBox(height: 20),

                          const Text(
                            'Commune de livraison',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 8),

                          deliveryFeesAsync.when(
                            data: (fees) {
                              if (fees.isEmpty) {
                                return const Text(
                                  'Aucune commune disponible',
                                );
                              }

                              return DropdownButtonFormField<
                                  String>(
                                value:
                                    cartState.commune,
                                isExpanded: true,
                                hint: const Text(
                                  'Sélectionnez une commune',
                                ),
                                decoration:
                                    InputDecoration(
                                  filled: true,
                                  fillColor:
                                      Colors.white,
                                  border:
                                      OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      8,
                                    ),
                                  ),
                                  enabledBorder:
                                      OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      8,
                                    ),
                                    borderSide:
                                        BorderSide(
                                      color: Colors
                                          .grey
                                          .withValues(
                                        alpha:
                                            0.3,
                                      ),
                                    ),
                                  ),
                                  focusedBorder:
                                      OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      8,
                                    ),
                                    borderSide:
                                        const BorderSide(
                                      color: AppColors
                                          .primaire,
                                    ),
                                  ),
                                  contentPadding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                items:
                                    fees.map((fee) {
                                  return DropdownMenuItem<
                                      String>(
                                    value:
                                        fee.commune,
                                    child: Text(
                                      '${fee.commune} (${fee.frais.toInt()} FCFA)',
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val == null) {
                                    return;
                                  }

                                  final selectedFee =
                                      fees.firstWhere(
                                    (fee) =>
                                        fee.commune ==
                                        val,
                                  );

                                  ref
                                      .read(
                                        panierProvider
                                            .notifier,
                                      )
                                      .setCommune(
                                        val,
                                        selectedFee
                                            .frais,
                                      );
                                },
                              );
                            },
                            loading: () {
                              return const Center(
                                child:
                                    CircularProgressIndicator(),
                              );
                            },
                            error: (e, st) {
                              return Text(
                                'Erreur: $e',
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.red,
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          const Text(
                            'Adresse précise',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 8),

                          TextField(
                            controller:
                                _adresseController,
                            keyboardType:
                                TextInputType
                                    .streetAddress,
                            textInputAction:
                                TextInputAction.done,
                            minLines: 1,
                            maxLines: 2,
                            onSubmitted: (_) {
                              FocusScope.of(context)
                                  .unfocus();
                            },
                            decoration:
                                InputDecoration(
                              hintText:
                                  'Rue, quartier, repère...',
                              filled: true,
                              fillColor:
                                  Colors.white,
                              border:
                                  OutlineInputBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  8,
                                ),
                              ),
                              enabledBorder:
                                  OutlineInputBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  8,
                                ),
                                borderSide:
                                    BorderSide(
                                  color: Colors.grey
                                      .withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              focusedBorder:
                                  OutlineInputBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  8,
                                ),
                                borderSide:
                                    const BorderSide(
                                  color: AppColors
                                      .primaire,
                                ),
                              ),
                              contentPadding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],

                        // ------------------------------------------------------------
                        // RÉCAPITULATIF
                        // ------------------------------------------------------------

                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          children: [
                            const Text(
                              'Sous-total',
                              style: TextStyle(
                                color: AppColors
                                    .secondaire,
                              ),
                            ),
                            Text(
                              '${cartState.sousTotal.toInt()} FCFA',
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Frais de livraison',
                                style: TextStyle(
                                  color: AppColors
                                      .secondaire,
                                ),
                              ),
                            ),
                            Text(
                              cartState
                                          .fraisLivraison >
                                      0
                                  ? '${cartState.fraisLivraison.toInt()} FCFA'
                                  : 'Gratuit',
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        const Padding(
                          padding:
                              EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          child: Divider(),
                        ),

                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '${cartState.total.toInt()} FCFA',
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 20,
                                color: AppColors
                                    .primaire,
                              ),
                            ),
                          ],
                        ),

                        // ------------------------------------------------------------
                        // ERREUR
                        // ------------------------------------------------------------

                        if (_errorMessage != null)
                          Container(
                            width: double.infinity,
                            margin:
                                const EdgeInsets.only(
                              top: 16,
                            ),
                            padding:
                                const EdgeInsets.all(
                              12,
                            ),
                            decoration:
                                BoxDecoration(
                              color: Colors.red
                                  .withValues(
                                alpha: 0.08,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                8,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                const Icon(
                                  Icons
                                      .error_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(
                                  width: 8,
                                ),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 20),

                        // ------------------------------------------------------------
                        // BOUTON COMMANDER
                        // ------------------------------------------------------------

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed:
                                _isLoading
                                    ? null
                                    : _commander,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color:
                                          Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Commander',
                                    style:
                                        TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Permet de laisser un peu d'espace sous le bouton.
                  // Utile également lorsque le clavier est affiché.
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // PLACEHOLDER IMAGE
  // ---------------------------------------------------------------------------

  Widget _buildPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: AppColors.fond,
      child: const Icon(
        Icons.cake,
        color: AppColors.primaire,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // OPTION RETRAIT / LIVRAISON
  // ---------------------------------------------------------------------------

  Widget _buildRetraitOption({
    required String title,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final bool isSelected = value == groupValue;

    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 150,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.fond
              : Colors.white,
          border: Border.all(
            color: isSelected
                ? AppColors.primaire
                : Colors.grey.withValues(
                    alpha: 0.3,
                  ),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? AppColors.primaire
                  : Colors.grey,
              size: 20,
            ),

            const SizedBox(height: 8),

            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? AppColors.primaire
                    : AppColors.texte,
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/order.dart';
import '../../../theme/app_colors.dart';
import '../providers/admin_orders_provider.dart';

class AdminPreparationScreen extends ConsumerStatefulWidget {
  const AdminPreparationScreen({super.key});

  @override
  ConsumerState<AdminPreparationScreen> createState() =>
      _AdminPreparationScreenState();
}

class _AdminPreparationScreenState
    extends ConsumerState<AdminPreparationScreen> {
  static const _closedStatuses = {'annulee', 'refusee'};
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  _PreparationFilter _filter = _PreparationFilter.all;
  String? _updatingOrderId;

  String get _selectedDateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  DateTime? _scheduledDate(OrderModel order) {
    final slotDate = order.deliverySlotDate;
    if (slotDate != null && slotDate.isNotEmpty) {
      try {
        return DateUtils.dateOnly(DateTime.parse('${slotDate}T00:00:00'));
      } on FormatException {
        // Les anciennes commandes peuvent n'avoir que date_souhaitee.
      }
    }
    return order.dateSouhaitee == null
        ? null
        : DateUtils.dateOnly(order.dateSouhaitee!);
  }

  bool _isScheduledForSelectedDay(OrderModel order) {
    final scheduledDate = _scheduledDate(order);
    return scheduledDate != null &&
        DateFormat('yyyy-MM-dd').format(scheduledDate) == _selectedDateKey;
  }

  List<OrderModel> _applyFilter(List<OrderModel> orders) {
    final activeOrders = orders
        .where((order) => !_closedStatuses.contains(order.statutCommande))
        .where(_isScheduledForSelectedDay)
        .toList();

    switch (_filter) {
      case _PreparationFilter.toPrepare:
        return activeOrders.where((order) {
          return const {
            'en_attente_validation',
            'acceptee',
            'en_preparation',
          }.contains(order.statutCommande);
        }).toList();
      case _PreparationFilter.ready:
        return activeOrders
            .where((order) => order.statutCommande == 'prete')
            .toList();
      case _PreparationFilter.completed:
        return activeOrders
            .where((order) => order.statutCommande == 'livree')
            .toList();
      case _PreparationFilter.all:
        return activeOrders;
    }
  }

  Map<String, List<OrderModel>> _groupBySlot(List<OrderModel> orders) {
    final groups = <String, List<OrderModel>>{};
    for (final order in orders) {
      final label = order.deliverySlotLabel?.trim();
      final key = label != null && label.isNotEmpty
          ? label
          : order.dateSouhaitee == null
          ? 'Horaire à confirmer'
          : DateFormat('HH:mm').format(order.dateSouhaitee!);
      groups.putIfAbsent(key, () => []).add(order);
    }

    final keys = groups.keys.toList()
      ..sort((a, b) {
        final timeDifference = _minutesFromLabel(a) - _minutesFromLabel(b);
        return timeDifference == 0 ? a.compareTo(b) : timeDifference;
      });
    return {for (final key in keys) key: groups[key]!};
  }

  int _minutesFromLabel(String label) {
    final match = RegExp(r'(\d{1,2})\s*[:hH]\s*(\d{2})').firstMatch(label);
    if (match == null) return 24 * 60;
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  Map<String, int> _productQuantities(List<OrderModel> orders) {
    final quantities = <String, int>{};
    for (final order in orders) {
      for (final item in order.items) {
        final label = item.optionLabel.isEmpty
            ? item.nom
            : '${item.nom} · ${item.optionLabel}';
        quantities.update(
          label,
          (quantity) => quantity + item.quantite,
          ifAbsent: () => item.quantite,
        );
      }
    }
    return Map.fromEntries(
      quantities.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  Future<void> _chooseDate() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
      helpText: 'Choisir le jour de préparation',
      cancelText: 'Annuler',
      confirmText: 'Choisir',
    );
    if (selected != null && mounted) {
      setState(() => _selectedDate = DateUtils.dateOnly(selected));
    }
  }

  Future<void> _changeStatus(
    OrderModel order, {
    required String status,
    required String historyLabel,
    required String confirmation,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(confirmation),
        content: Text('Commande #${order.numero} · ${order.clientNom}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _updatingOrderId = order.id);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .update({
            'statut_commande': status,
            'historique_statuts': FieldValue.arrayUnion([
              {'statut': historyLabel, 'date': Timestamp.now()},
            ]),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Commande #${order.numero} mise à jour.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La mise à jour a échoué. Réessaie dans un instant.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  Future<void> _callClient(String phone) async {
    final normalizedPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final launched = await launchUrl(Uri(scheme: 'tel', path: normalizedPhone));
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir l’application téléphone.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(adminPreparationOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Préparation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(adminPreparationOrdersProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaire),
        ),
        error: (_, _) => _PreparationLoadError(
          onRetry: () => ref.invalidate(adminPreparationOrdersProvider),
        ),
        data: (allOrders) {
          final dayOrders = allOrders
              .where(_isScheduledForSelectedDay)
              .where((order) => !_closedStatuses.contains(order.statutCommande))
              .toList();
          final visibleOrders = _applyFilter(allOrders);
          final groups = _groupBySlot(visibleOrders);
          final quantities = _productQuantities(dayOrders);
          final totalItems = quantities.values.fold<int>(
            0,
            (total, quantity) => total + quantity,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _DateSelector(
                selectedDate: _selectedDate,
                onPrevious: () => setState(() {
                  _selectedDate = _selectedDate.subtract(
                    const Duration(days: 1),
                  );
                }),
                onNext: () => setState(() {
                  _selectedDate = _selectedDate.add(const Duration(days: 1));
                }),
                onChoose: _chooseDate,
                onToday: () => setState(() {
                  _selectedDate = DateUtils.dateOnly(DateTime.now());
                }),
              ),
              const SizedBox(height: 16),
              _DaySummary(orders: dayOrders, totalItems: totalItems),
              const SizedBox(height: 16),
              if (dayOrders.isNotEmpty) ...[
                _ProductVolumeCard(quantities: quantities),
                const SizedBox(height: 20),
              ],
              _buildFilters(),
              const SizedBox(height: 12),
              if (visibleOrders.isEmpty)
                _PreparationEmptyState(
                  date: _selectedDate,
                  hasOrdersBeforeFilter: dayOrders.isNotEmpty,
                )
              else
                for (final entry in groups.entries) ...[
                  _SlotHeader(label: entry.key, orders: entry.value),
                  const SizedBox(height: 10),
                  for (final order in entry.value) ...[
                    _PreparationOrderCard(
                      order: order,
                      action: _nextAction(order),
                      isUpdating: _updatingOrderId == order.id,
                      onCallClient: order.clientTelephone.isEmpty
                          ? null
                          : () => _callClient(order.clientTelephone),
                      onValidate:
                          order.statutCommande == 'en_attente_validation'
                          ? () => context.go('/admin/commandes')
                          : null,
                      onAdvance:
                          _nextAction(order) == null || _updatingOrderId != null
                          ? null
                          : () => _runNextAction(order),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _PreparationFilter.values) ...[
            FilterChip(
              label: Text(filter.label),
              selected: _filter == filter,
              onSelected: (_) => setState(() => _filter = filter),
              selectedColor: AppColors.primaire.withValues(alpha: 0.14),
              checkmarkColor: AppColors.primaire,
              side: BorderSide(
                color: _filter == filter
                    ? AppColors.primaire.withValues(alpha: 0.35)
                    : AppColors.secondaire.withValues(alpha: 0.2),
              ),
              showCheckmark: false,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  _OrderAction? _nextAction(OrderModel order) {
    if (order.statutPaiement != 'confirme') return null;
    switch (order.statutCommande) {
      case 'acceptee':
        return const _OrderAction(
          status: 'en_preparation',
          historyLabel: 'mise_en_preparation',
          label: 'Démarrer la préparation',
          confirmation: 'Commencer la préparation ?',
          icon: Icons.kitchen_rounded,
        );
      case 'en_preparation':
        return const _OrderAction(
          status: 'prete',
          historyLabel: 'commande_prete',
          label: 'Marquer comme prête',
          confirmation: 'Marquer la commande comme prête ?',
          icon: Icons.check_circle_outline_rounded,
        );
      case 'prete':
        return _OrderAction(
          status: 'livree',
          historyLabel: 'commande_livree',
          label: order.modeLivraison == 'livraison'
              ? 'Confirmer la livraison'
              : 'Confirmer le retrait',
          confirmation: order.modeLivraison == 'livraison'
              ? 'Confirmer que la commande a été livrée ?'
              : 'Confirmer que la commande a été retirée ?',
          icon: order.modeLivraison == 'livraison'
              ? Icons.local_shipping_outlined
              : Icons.storefront_outlined,
        );
    }
    return null;
  }

  Future<void> _runNextAction(OrderModel order) async {
    final action = _nextAction(order);
    if (action == null) return;
    await _changeStatus(
      order,
      status: action.status,
      historyLabel: action.historyLabel,
      confirmation: action.confirmation,
    );
  }
}

enum _PreparationFilter {
  all('Toutes'),
  toPrepare('À traiter'),
  ready('Prêtes'),
  completed('Terminées');

  const _PreparationFilter(this.label);
  final String label;
}

class _OrderAction {
  final String status;
  final String historyLabel;
  final String label;
  final String confirmation;
  final IconData icon;

  const _OrderAction({
    required this.status,
    required this.historyLabel,
    required this.label,
    required this.confirmation,
    required this.icon,
  });
}

class _DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onChoose;
  final VoidCallback onToday;

  const _DateSelector({
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
    required this.onChoose,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final isToday = DateUtils.isSameDay(selectedDate, today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'Jour précédent',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: InkWell(
                onTap: onChoose,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('EEEE', 'fr_FR').format(selectedDate),
                        style: const TextStyle(
                          color: AppColors.secondaire,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              DateFormat(
                                'd MMMM yyyy',
                                'fr_FR',
                              ).format(selectedDate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.texte,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(Icons.calendar_month_outlined, size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Jour suivant',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: isToday ? null : onToday,
            icon: const Icon(Icons.today_outlined, size: 18),
            label: Text(isToday ? 'Aujourd’hui' : 'Revenir à aujourd’hui'),
          ),
        ),
      ],
    );
  }
}

class _DaySummary extends StatelessWidget {
  final List<OrderModel> orders;
  final int totalItems;

  const _DaySummary({required this.orders, required this.totalItems});

  @override
  Widget build(BuildContext context) {
    final toPrepare = orders.where((order) {
      return const {
        'en_attente_validation',
        'acceptee',
        'en_preparation',
      }.contains(order.statutCommande);
    }).length;
    final ready = orders
        .where((order) => order.statutCommande == 'prete')
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.secondaire.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          _SummaryMetric(value: '${orders.length}', label: 'commandes'),
          _SummaryMetric(value: '$toPrepare', label: 'à traiter'),
          _SummaryMetric(value: '$ready', label: 'prêtes'),
          _SummaryMetric(value: '$totalItems', label: 'articles'),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.texte,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.secondaire, fontSize: 10),
        ),
      ],
    ),
  );
}

class _ProductVolumeCard extends StatelessWidget {
  final Map<String, int> quantities;

  const _ProductVolumeCard({required this.quantities});

  @override
  Widget build(BuildContext context) {
    final entries = quantities.entries.toList();
    final shown = entries.take(6).toList();
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.secondaire.withValues(alpha: 0.12)),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(
          Icons.inventory_2_outlined,
          color: AppColors.primaire,
        ),
        title: const Text(
          'Quantités commandées',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${quantities.values.fold<int>(0, (total, quantity) => total + quantity)} articles commandés',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        children: [
          for (final entry in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(child: Text(entry.key)),
                  const SizedBox(width: 12),
                  Text(
                    '× ${entry.value}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          if (entries.length > shown.length)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Et ${entries.length - shown.length} autre${entries.length - shown.length > 1 ? 's' : ''} référence${entries.length - shown.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: AppColors.secondaire,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SlotHeader extends StatelessWidget {
  final String label;
  final List<OrderModel> orders;

  const _SlotHeader({required this.label, required this.orders});

  @override
  Widget build(BuildContext context) {
    final itemCount = orders.fold<int>(
      0,
      (total, order) =>
          total +
          order.items.fold<int>(
            0,
            (quantityTotal, item) => quantityTotal + item.quantite,
          ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 19,
            color: AppColors.primaire,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            '${orders.length} cmd · $itemCount art.',
            style: const TextStyle(color: AppColors.secondaire, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PreparationOrderCard extends StatelessWidget {
  final OrderModel order;
  final _OrderAction? action;
  final bool isUpdating;
  final VoidCallback? onCallClient;
  final VoidCallback? onValidate;
  final VoidCallback? onAdvance;

  const _PreparationOrderCard({
    required this.order,
    required this.action,
    required this.isUpdating,
    required this.onCallClient,
    required this.onValidate,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    final actionConfig = action;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.secondaire.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.clientNom.isEmpty ? 'Client' : order.clientNom,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.texte,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Commande #${order.numero}',
                        style: const TextStyle(
                          color: AppColors.secondaire,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _OrderStatusPill(status: order.statutCommande),
              ],
            ),
            const Divider(height: 22),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 38,
                      child: Text(
                        '× ${item.quantite}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaire,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.optionLabel.isEmpty
                            ? item.nom
                            : '${item.nom} · ${item.optionLabel}',
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            _OrderInfoLine(
              icon: order.modeLivraison == 'livraison'
                  ? Icons.local_shipping_outlined
                  : Icons.storefront_outlined,
              text: order.modeLivraison == 'livraison'
                  ? [order.commune, order.adresseLivraison]
                        .where((part) => part != null && part.trim().isNotEmpty)
                        .join(' · ')
                  : 'Retrait en boutique',
            ),
            if (order.statutCommande == 'acceptee' &&
                order.statutPaiement != 'confirme') ...[
              const SizedBox(height: 6),
              const _OrderInfoLine(
                icon: Icons.hourglass_top_rounded,
                text: 'En attente du paiement',
                color: Color(0xFF9A6B00),
              ),
            ],
            if (onCallClient != null ||
                actionConfig != null ||
                onValidate != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onCallClient != null)
                    OutlinedButton.icon(
                      onPressed: onCallClient,
                      icon: const Icon(Icons.phone_outlined, size: 17),
                      label: const Text('Appeler'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  if (onValidate != null)
                    FilledButton.tonalIcon(
                      onPressed: onValidate,
                      icon: const Icon(Icons.fact_check_outlined, size: 17),
                      label: const Text('À valider dans Commandes'),
                    ),
                  if (actionConfig != null)
                    FilledButton.icon(
                      onPressed: isUpdating ? null : onAdvance,
                      icon: isUpdating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(actionConfig.icon, size: 17),
                      label: Text(
                        isUpdating ? 'Mise à jour…' : actionConfig.label,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _OrderInfoLine({
    required this.icon,
    required this.text,
    this.color = AppColors.secondaire,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 17, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text.isEmpty ? 'Adresse non renseignée' : text,
          style: TextStyle(color: color, fontSize: 13),
        ),
      ),
    ],
  );
}

class _OrderStatusPill extends StatelessWidget {
  final String status;

  const _OrderStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = switch (status) {
      'en_attente_validation' => (
        'À valider',
        const Color(0xFFFFF2D6),
        const Color(0xFF805B00),
      ),
      'acceptee' => (
        'Acceptée',
        const Color(0xFFEAF2FF),
        const Color(0xFF2458A6),
      ),
      'en_preparation' => (
        'En préparation',
        const Color(0xFFE5F1FF),
        const Color(0xFF2458A6),
      ),
      'prete' => ('Prête', const Color(0xFFE7F5EC), const Color(0xFF277143)),
      'livree' => (
        'Terminée',
        const Color(0xFFEAF5F2),
        const Color(0xFF267260),
      ),
      _ => (status, const Color(0xFFF0F0F0), AppColors.secondaire),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: config.$2,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        config.$1,
        style: TextStyle(
          color: config.$3,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PreparationEmptyState extends StatelessWidget {
  final DateTime date;
  final bool hasOrdersBeforeFilter;

  const _PreparationEmptyState({
    required this.date,
    required this.hasOrdersBeforeFilter,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.secondaire.withValues(alpha: 0.12)),
    ),
    child: Column(
      children: [
        Icon(
          hasOrdersBeforeFilter
              ? Icons.filter_list_off_rounded
              : Icons.event_available_outlined,
          size: 42,
          color: AppColors.primaire,
        ),
        const SizedBox(height: 12),
        Text(
          hasOrdersBeforeFilter
              ? 'Aucune commande dans ce filtre'
              : 'Aucune commande prévue',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 5),
        Text(
          hasOrdersBeforeFilter
              ? 'Change le filtre pour voir les autres commandes du jour.'
              : 'Pour le ${DateFormat('d MMMM', 'fr_FR').format(date)}, les commandes apparaîtront ici dès qu’un créneau sera réservé.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.secondaire, height: 1.4),
        ),
      ],
    ),
  );
}

class _PreparationLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _PreparationLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 44,
            color: AppColors.secondaire,
          ),
          const SizedBox(height: 12),
          const Text(
            'Le planning n’a pas pu être chargé.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}

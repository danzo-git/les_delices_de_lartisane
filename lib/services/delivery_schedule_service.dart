import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/delivery_schedule.dart';
import '../models/order.dart';

class DeliveryScheduleService {
  DeliveryScheduleService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> get _settingsRef =>
      _firestore.collection('delivery_settings').doc('default');

  Future<DeliveryScheduleSettings> getSettings() async {
    final snapshot = await _settingsRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      return const DeliveryScheduleSettings();
    }
    return DeliveryScheduleSettings.fromMap(snapshot.data()!);
  }

  Future<void> saveSettings(DeliveryScheduleSettings settings) async {
    await _settingsRef.set({
      ...settings.toMap(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<DeliverySlotReconciliationResult> reconcileUsage(DateTime date) async {
    final callable = _functions.httpsCallable('reconcileDeliverySlotUsage');
    final response = await callable.call({'date': deliveryDateKey(date)});
    return DeliverySlotReconciliationResult.fromMap(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<DeliveryAvailability> getAvailability(DateTime date) async {
    final settings = await getSettings();
    if (!settings.enabled) {
      return const DeliveryAvailability(enabled: false, slots: []);
    }

    final callable = _functions.httpsCallable('getAvailableDeliverySlots');
    final response = await callable.call({'date': deliveryDateKey(date)});
    final data = Map<String, dynamic>.from(response.data as Map);
    final rawSlots = data['slots'] as List<dynamic>? ?? const [];

    return DeliveryAvailability(
      enabled: data['enabled'] as bool? ?? false,
      slots: rawSlots
          .whereType<Map>()
          .map(
            (slot) =>
                AvailableDeliverySlot.fromMap(Map<String, dynamic>.from(slot)),
          )
          .toList(),
    );
  }

  Future<String> createOrder(
    OrderModel order, {
    AvailableDeliverySlot? slot,
  }) async {
    final payload = order.toMap();
    payload['date_souhaitee'] = order.dateSouhaitee?.toUtc().toIso8601String();
    payload['created_at'] = order.createdAt?.toUtc().toIso8601String();
    payload.remove('historique_statuts');

    final callable = _functions.httpsCallable('createOrderWithSlot');
    final response = await callable.call({
      'order_id': order.id,
      'order': payload,
      'slot_id': slot?.id,
      'slot_date': slot?.dateKey,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['order_id'] as String? ?? order.id;
  }
}

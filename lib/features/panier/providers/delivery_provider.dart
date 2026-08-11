import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/delivery_fee.dart';
import '../../../services/firestore_service.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final deliveryFeesProvider = FutureProvider<List<DeliveryFee>>((ref) async {
  final firestoreService = ref.read(firestoreServiceProvider);
  return await firestoreService.getDeliveryFees();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/order.dart';
import '../../../services/firestore_service.dart';
import '../../auth/providers/auth_provider.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final orderStreamProvider = StreamProvider.family<OrderModel?, String>((ref, orderId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.streamOrder(orderId);
});

final userOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final authState = ref.watch(authProvider);
  final userId = authState.user?.uid;
  
  if (userId == null) {
    return Stream.value([]);
  }
  
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserOrders(userId);
});

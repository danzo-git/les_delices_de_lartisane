import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/order.dart';
import '../../../models/user_profile.dart';

final adminDashboardOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('orders')
      .orderBy('created_at', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
            .toList(),
      );
});

final adminDashboardUsersProvider = StreamProvider<List<UserProfile>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => UserProfile.fromMap(doc.data(), doc.id))
            .toList(),
      );
});

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

/// Modèle d'une notification in-app
class AppNotification {
  final String id;
  final String titre;
  final String corps;
  final String? orderId;
  final String type;
  final bool lu;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.titre,
    required this.corps,
    this.orderId,
    required this.type,
    required this.lu,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      titre: data['titre'] as String? ?? '',
      corps: data['corps'] as String? ?? '',
      orderId: data['order_id'] as String?,
      type: data['type'] as String? ?? 'order_status_update',
      lu: data['lu'] as bool? ?? false,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Stream des notifications de l'utilisateur connecté, triées par date décroissante
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final authState = ref.watch(authProvider);
  final uid = authState.user?.uid;

  if (uid == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .orderBy('created_at', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(AppNotification.fromFirestore).toList());
});

/// Nombre de notifications non lues
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.maybeWhen(
    data: (list) => list.where((n) => !n.lu).length,
    orElse: () => 0,
  );
});

/// Marque une notification comme lue
Future<void> markNotificationAsRead(String uid, String notifId) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .doc(notifId)
      .update({'lu': true});
}

/// Marque toutes les notifications comme lues
Future<void> markAllNotificationsAsRead(String uid) async {
  final batch = FirebaseFirestore.instance.batch();
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .where('lu', isEqualTo: false)
      .get();

  for (final doc in snap.docs) {
    batch.update(doc.reference, {'lu': true});
  }
  await batch.commit();
}

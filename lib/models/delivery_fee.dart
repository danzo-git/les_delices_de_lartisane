import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryFee {
  final String id;
  final String commune;
  final double frais;
  final bool actif;

  DeliveryFee({
    required this.id,
    required this.commune,
    required this.frais,
    required this.actif,
  });

  factory DeliveryFee.fromMap(Map<String, dynamic> map, String id) {
    return DeliveryFee(
      id: id,
      commune: map['commune'] as String? ?? '',
      frais: (map['frais'] as num?)?.toDouble() ?? 0.0,
      actif: map['actif'] as bool? ?? false,
    );
  }
}

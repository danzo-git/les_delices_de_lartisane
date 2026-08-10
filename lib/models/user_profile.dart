import 'package:cloud_firestore/cloud_firestore.dart';

class UserAddress {
  final String label;
  final String commune;
  final String details;

  UserAddress({
    required this.label,
    required this.commune,
    required this.details,
  });

  factory UserAddress.fromMap(Map<String, dynamic> map) {
    return UserAddress(
      label: map['label'] as String? ?? '',
      commune: map['commune'] as String? ?? '',
      details: map['details'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'commune': commune,
      'details': details,
    };
  }
}

class UserProfile {
  final String uid;
  final String nom;
  final String telephone;
  final String email;
  final String role; // "client" | "admin"
  final List<UserAddress> adresses;
  final DateTime? createdAt;

  UserProfile({
    required this.uid,
    required this.nom,
    required this.telephone,
    required this.email,
    required this.role,
    required this.adresses,
    this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return UserProfile(
      uid: uid,
      nom: map['nom'] as String? ?? '',
      telephone: map['telephone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'client',
      adresses: (map['adresses'] as List<dynamic>?)
              ?.map((item) => UserAddress.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: map['created_at'] != null
          ? (map['created_at'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'telephone': telephone,
      'email': email,
      'role': role,
      'adresses': adresses.map((a) => a.toMap()).toList(),
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user_profile.dart';
import '../../../services/notification_service.dart';

/// StreamProvider pour observer le changement d'état Firebase Auth
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// État du processus d'authentification
class AuthState {
  final User? user;
  final UserProfile? profile;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.profile,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    User? user,
    UserProfile? profile,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Notifier pour la gestion de l'authentification
class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  void _init() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _listenToUserProfile(user.uid);
      } else {
        state = const AuthState();
      }
    });
  }

  /// Écoute en temps réel le document users/{uid} — prend en compte
  /// les changements de rôle sans déconnexion/reconnexion.
  void _listenToUserProfile(String uid) {
    NotificationService.instance.init(uid);
    
    _firestore.collection('users').doc(uid).snapshots().listen((doc) {
      if (doc.exists && doc.data() != null) {
        final profile = UserProfile.fromMap(doc.data()!, uid);
        state = state.copyWith(user: _auth.currentUser, profile: profile);
      } else {
        state = state.copyWith(user: _auth.currentUser);
      }
    }, onError: (_) {
      state = state.copyWith(user: _auth.currentUser);
    });
  }

  /// Efface les erreurs en cours
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Connexion avec Email / Mot de passe
  Future<bool> login({
    required String inputEmailOrPhone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      String email = inputEmailOrPhone.trim();

      // Si l'identifiant renseigné est un numéro de téléphone (pas d'arobase)
      if (!email.contains('@')) {
        // Recherche dans Firestore l'email associé au numéro de téléphone
        final snapshot = await _firestore
            .collection('users')
            .where('telephone', isEqualTo: email)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          email = snapshot.docs.first.data()['email'] as String? ?? email;
        }
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Le profil sera chargé automatiquement via _listenToUserProfile
        // déclenché par authStateChanges(). Pas besoin d'appel explicite.
        state = state.copyWith(isLoading: false);
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Échec de la connexion.',
      );
      return false;
    } on FirebaseAuthException catch (e) {
      String message = 'Une erreur est survenue lors de la connexion.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Identifiant ou mot de passe incorrect.';
      } else if (e.code == 'invalid-email') {
        message = 'Adresse email invalide.';
      } else if (e.code == 'user-disabled') {
        message = 'Ce compte a été désactivé.';
      }
      state = state.copyWith(isLoading: false, errorMessage: message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur réseau ou serveur. Veuillez réessayer.',
      );
      return false;
    }
  }

  /// Inscription avec Nom, Téléphone, Email, Mot de passe
  Future<bool> signup({
    required String nom,
    required String telephone,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // 1. Création dans Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Échec de la création du compte.',
        );
        return false;
      }

      // Mise à jour du nom d'affichage Auth
      await user.updateDisplayName(nom.trim());

      // 2. Création exacte du document utilisateur dans Firestore
      final userProfileMap = {
        'nom': nom.trim(),
        'telephone': telephone.trim(),
        'email': email.trim(),
        'role': 'client', // Toujours client à l'inscription
        'adresses': [],
        'created_at': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(user.uid).set(userProfileMap);

      final newProfile = UserProfile(
        uid: user.uid,
        nom: nom.trim(),
        telephone: telephone.trim(),
        email: email.trim(),
        role: 'client',
        adresses: [],
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        user: user,
        profile: newProfile,
        isLoading: false,
      );

      return true;
    } on FirebaseAuthException catch (e) {
      String message = 'Une erreur est survenue lors de l\'inscription.';
      if (e.code == 'email-already-in-use') {
        message = 'Un compte existe déjà avec cet email.';
      } else if (e.code == 'weak-password') {
        message = 'Le mot de passe doit contenir au moins 6 caractères.';
      } else if (e.code == 'invalid-email') {
        message = 'Adresse email invalide.';
      }
      state = state.copyWith(isLoading: false, errorMessage: message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur lors de la création du profil: $e',
      );
      return false;
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    await _auth.signOut();
    state = const AuthState();
  }
}

/// Provider global d'authentification
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

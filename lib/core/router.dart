import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/splash_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    // Placeholder route pour l'accueil/catalogue avant son développement
    GoRoute(
      path: '/home',
      builder: (context, state) => const Scaffold(
        body: Center(
          child: Text('Écran Accueil / Catalogue (À venir)'),
        ),
      ),
    ),
  ],
);

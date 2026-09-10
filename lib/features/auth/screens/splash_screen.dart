import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../theme/app_colors.dart';
import '../../../services/notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  void _checkAuthState() {
    // Petit délai d'affichage splash (ex: 2s) pour la fluidité de la maquette
    _timer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        if (NotificationService.pendingRoute != null) {
          final route = NotificationService.pendingRoute!;
          NotificationService.pendingRoute = null;
          context.go(route);
        } else {
          context.go('/home');
        }
      } else {
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Logo centré conforme à l'écran 01 SPLASH
              const AppLogo(
                iconSize: 90.0,
                titleFontSize: 32.0,
                showTagline: true,
              ),
              const Spacer(),
              // Indicatif de chargement en bas
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaire),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

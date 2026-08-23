import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.fond,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.dashboard_rounded,
                  size: 40,
                  color: AppColors.primaire,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Dashboard',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.texte,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Les statistiques seront disponibles prochainement.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaire,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

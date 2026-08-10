import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../theme/app_colors.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    final authNotifier = ref.read(authProvider.notifier);

    final success = await authNotifier.login(
      inputEmailOrPhone: _emailOrPhoneController.text,
      password: _passwordController.text,
    );

    if (success && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // En-tête Logo
              const AppLogo(
                iconSize: 56.0,
                titleFontSize: 24.0,
                showTagline: true,
              ),
              const SizedBox(height: 32),

              // Titre et sous-titre conforme à l'écran 02
              Text(
                'Bienvenue !',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: AppColors.texte,
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Connectez-vous à votre compte',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaire,
                ),
              ),
              const SizedBox(height: 28),

              // Formulaire
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Champ Téléphone ou Email
                    TextFormField(
                      controller: _emailOrPhoneController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Téléphone ou email',
                        prefixIcon: Icon(Icons.person_outline, color: AppColors.secondaire),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez saisir votre téléphone ou email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Champ Mot de passe
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.secondaire),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.secondaire,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez saisir votre mot de passe';
                        }
                        return null;
                      },
                    ),

                    // Lien Mot de passe oublié ?
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // TODO: Écran mot de passe oublié (à créer plus tard)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Réinitialisation du mot de passe à venir.'),
                            ),
                          );
                        },
                        child: Text(
                          'Mot de passe oublié ?',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primaire,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Message d'erreur clair sous le formulaire
                    if (authState.errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                authState.errorMessage!,
                                style: const TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Bouton Se connecter
                    ElevatedButton(
                      onPressed: authState.isLoading ? null : _handleLogin,
                      child: authState.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Se connecter'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              // Séparateur "ou continuer avec"
              Row(
                children: [
                  const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'ou continuer avec',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaire,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                ],
              ),
              const SizedBox(height: 20),

              // Boutons Réseaux Sociaux (Google / Apple visuels de la maquette)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Action visuelle pour la maquette
                      },
                      icon: const Icon(Icons.g_mobiledata, size: 24, color: Colors.red),
                      label: const Text('Google', style: TextStyle(color: AppColors.texte, fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Action visuelle pour la maquette
                      },
                      icon: const Icon(Icons.apple, size: 22, color: Colors.black),
                      label: const Text('Apple', style: TextStyle(color: AppColors.texte, fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              // Lien d'inscription
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Pas encore de compte ? ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.texte,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ref.read(authProvider.notifier).clearError();
                      context.go('/signup');
                    },
                    child: Text(
                      'S\'inscrire',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.primaire,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

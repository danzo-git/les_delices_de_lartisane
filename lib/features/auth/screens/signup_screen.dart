import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../theme/app_colors.dart';
import '../providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nomController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    final authNotifier = ref.read(authProvider.notifier);

    final success = await authNotifier.signup(
      nom: _nomController.text,
      telephone: _telephoneController.text,
      email: _emailController.text,
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.texte),
          onPressed: () {
            ref.read(authProvider.notifier).clearError();
            context.go('/login');
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              const AppLogo(
                iconSize: 50.0,
                titleFontSize: 22.0,
                showTagline: false,
              ),
              const SizedBox(height: 24),

              // Titre
              Text(
                'Créer un compte',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: AppColors.texte,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Rejoignez Les Délices de l\'Artisane',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaire,
                ),
              ),
              const SizedBox(height: 24),

              // Formulaire
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Champ Nom complet
                    TextFormField(
                      controller: _nomController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Nom complet',
                        prefixIcon: Icon(Icons.person_outline, color: AppColors.secondaire),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez saisir votre nom';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Champ Téléphone
                    TextFormField(
                      controller: _telephoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'Téléphone (ex: 0701020304)',
                        prefixIcon: Icon(Icons.phone_outlined, color: AppColors.secondaire),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez saisir votre numéro de téléphone';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Champ Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined, color: AppColors.secondaire),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez saisir votre email';
                        }
                        if (!value.contains('@')) {
                          return 'Veuillez saisir un email valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Champ Mot de passe
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Mot de passe (6 caractères min.)',
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
                        if (value == null || value.length < 6) {
                          return 'Le mot de passe doit contenir au moins 6 caractères';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Message d'erreur
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

                    // Bouton S'inscrire
                    ElevatedButton(
                      onPressed: authState.isLoading ? null : _handleSignup,
                      child: authState.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('S\'inscrire'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              // Lien de connexion
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Déjà un compte ? ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.texte,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ref.read(authProvider.notifier).clearError();
                      context.go('/login');
                    },
                    child: Text(
                      'Se connecter',
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

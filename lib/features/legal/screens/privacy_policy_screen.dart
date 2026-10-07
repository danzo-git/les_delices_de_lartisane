import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Politique de confidentialité',
          style: TextStyle(
            color: AppColors.texte,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.texte),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dernière mise à jour : 16 septembre 2026',
              style: TextStyle(
                color: AppColors.secondaire,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: '1. Qui sommes-nous',
              content: 'Les Délices de l\'Artisane est un commerce artisanal de mignardises basé à Abidjan, Côte d\'Ivoire. Cette politique explique quelles données personnelles sont collectées via notre application mobile, pourquoi, et comment elles sont protégées.',
            ),
            _buildSection(
              title: '2. Données que nous collectons',
              content: '• Nom, téléphone, email : créer votre compte et vous contacter au sujet de vos commandes\n• Adresse de livraison : livrer votre commande à la bonne adresse\n• Historique de commandes : suivre vos commandes et y accéder plus tard\n• Jeton de notification (FCM) : vous prévenir des changements de statut de votre commande\n\nNous ne collectons aucune donnée de carte bancaire ou de mobile money : les paiements sont traités directement par notre prestataire de paiement, GeniusPay, qui applique ses propres mesures de sécurité.',
            ),
            _buildSection(
              title: '3. Partage des données',
              content: 'Vos données sont hébergées sur les serveurs de Google Firebase, notre fournisseur d\'infrastructure technique. Elles ne sont partagées avec aucun tiers à des fins commerciales ou publicitaires. Lors d\'un paiement, votre nom et votre numéro de téléphone sont transmis à GeniusPay, notre prestataire de paiement, uniquement pour traiter la transaction.',
            ),
            _buildSection(
              title: '4. Conservation des données',
              content: 'Vos données sont conservées tant que votre compte reste actif. Vous pouvez demander la suppression de votre compte et de vos données à tout moment en nous contactant.',
            ),
            _buildSection(
              title: '5. Vos droits',
              content: '• Accéder aux données que nous détenons sur vous\n• Corriger une information inexacte\n• Demander la suppression de votre compte et de vos données\n\nPour exercer l\'un de ces droits, contactez-nous à l\'adresse ci-dessous.',
            ),
            _buildSection(
              title: '6. Sécurité',
              content: 'L\'accès à vos données est protégé par authentification, et des règles de sécurité empêchent tout accès non autorisé à vos commandes ou à votre profil par d\'autres utilisateurs.',
            ),
            _buildSection(
              title: '7. Modifications de cette politique',
              content: 'Cette politique peut être mise à jour ponctuellement. La date de dernière mise à jour est indiquée en haut de cet écran.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Contact : kouamedenzel09@gmail.com',
              style: TextStyle(
                color: AppColors.texte,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primaire,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: AppColors.texte,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

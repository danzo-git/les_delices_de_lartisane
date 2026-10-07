//construire une page pour les faq de l'application avec flutter

//voici les infos a afficher
/*
 * # FAQ — Les Délices de l'Artisane

**Comment passer une commande ?**
Parcourez le catalogue, ajoutez les produits souhaités à votre panier, choisissez le retrait en boutique ou la livraison, indiquez la date souhaitée, puis validez. L'artisane confirme ensuite la faisabilité de votre commande avant de vous demander le paiement.

**Pourquoi dois-je attendre une validation avant de payer ?**
Chaque commande est faite à la main. L'artisane vérifie qu'elle peut respecter votre délai avant de vous demander le paiement — vous ne payez donc jamais pour une commande qui ne pourrait pas être honorée à temps.

**Quels sont les moyens de paiement acceptés ?**
Wave, Orange Money, MTN Mobile Money et Moov Money, directement depuis l'application.

**Ma commande a été refusée, pourquoi ?**
L'artisane peut refuser une commande si elle ne peut pas la préparer dans le délai souhaité (charge de travail, quantité demandée, etc.). Le motif du refus s'affiche dans le suivi de votre commande. Aucun paiement n'est prélevé si votre commande est refusée.

**Puis-je annuler une commande ?**
Oui, tant qu'elle est encore "en attente de validation". Une fois acceptée par l'artisane, l'annulation n'est plus possible depuis l'application — contactez-nous directement via WhatsApp.

**Quelles sont les zones de livraison ?**
La livraison est disponible à Abidjan, avec un tarif fixé selon la commune. Le tarif s'affiche automatiquement selon votre choix dans le panier.

**Comment suivre ma commande ?**
Depuis l'onglet "Commandes", vous voyez en temps réel son statut : en attente, acceptée, en préparation, prête, livrée.

**Comment contacter l'artisane pour une demande particulière ?**
Utilisez le bouton "Besoin d'aide ? Contactez-nous" présent sur les écrans de commande, qui ouvre une conversation WhatsApp directe.

**Comment supprimer mon compte et mes données ?**
Rendez-vous dans Mon compte > Paramètres > Supprimer mon compte, ou contactez-nous à kouamedenzel09@gmail.com.
 */


import 'package:flutter/material.dart';

class FAQScreen extends StatelessWidget {
   FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C2C2C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'FAQ',
          style: TextStyle(
            color: Color(0xFF2C2C2C),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _faqs.length,
        itemBuilder: (context, index) {
          final faq = _faqs[index];
          return _buildFAQItem(context, faq);
        },
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, Map<String, String> faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          faq['question']!,
          style: const TextStyle(
            color: Color(0xFF2C2C2C),
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              faq['answer']!,
              style: const TextStyle(
                color: Color(0xFF2C2C2C),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  final List<Map<String, String>> _faqs = [
    {
      'question': 'Comment passer une commande ?',
      'answer':
      'Parcourez le catalogue, ajoutez les produits souhaités à votre panier, choisissez le retrait en boutique ou la livraison, indiquez la date souhaitée, puis validez. L\'artisane confirme ensuite la faisabilité de votre commande avant de vous demander le paiement.',
    },
    {
      'question': 'Pourquoi dois-je attendre une validation avant de payer ?',
      'answer':
      'Chaque commande est faite à la main. L\'artisane vérifie qu\'elle peut respecter votre délai avant de vous demander le paiement — vous ne payez donc jamais pour une commande qui ne pourrait pas être honorée à temps.',
    },
    {
      'question': 'Quels sont les moyens de paiement acceptés ?',
      'answer':
      'Wave, Orange Money, MTN Mobile Money et Moov Money, directement depuis l\'application.',
    },
    {
      'question': 'Ma commande a été refusée, pourquoi ?',
      'answer':
      'L\'artisane peut refuser une commande si elle ne peut pas la préparer dans le délai souhaité (charge de travail, quantité demandée, etc.). Le motif du refus s\'affiche dans le suivi de votre commande. Aucun paiement n\'est prélevé si votre commande est refusée.',
    },
    {
      'question': 'Puis-je annuler une commande ?',
      'answer':
      'Oui, tant qu\'elle est encore "en attente de validation". Une fois acceptée par l\'artisane, l\'annulation n\'est plus possible depuis l\'application — contactez-nous directement via WhatsApp.',
    },
    {
      'question': 'Quelles sont les zones de livraison ?',
      'answer':
      'La livraison est disponible à Abidjan, avec un tarif fixé selon la commune. Le tarif s\'affiche automatiquement selon votre choix dans le panier.',
    },
    {
      'question': 'Comment suivre ma commande ?',
      'answer':
      'Depuis l\'onglet "Commandes", vous voyez en temps réel son statut : en attente, acceptée, en préparation, prête, livrée.',
    },
    {
      'question': 'Comment contacter l\'artisane pour une demande particulière ?',
      'answer':
      'Utilisez le bouton "Besoin d\'aide ? Contactez-nous" présent sur les écrans de commande, qui ouvre une conversation WhatsApp directe.',
    },
    {
      'question': 'Comment supprimer mon compte et mes données ?',
      'answer':
      'Rendez-vous dans Mon compte > Paramètres > Supprimer mon compte, ou contactez-nous à kouamedenzel09@gmail.com.',
    },
  ];
}

# Cahier des charges — Application de vente de mignardises

## 1. Contexte et objectifs

### 1.1 Contexte
Une artisane confectionne des mignardises (petits fours, pâtisseries fines) et vend actuellement sans outil digital dédié. L'objectif est de lui offrir une application mobile qui présente son travail et permette à ses clients de commander et payer directement en ligne.

### 1.2 Objectifs de l'application
- Faire connaître l'artisane et son savoir-faire (vitrine)
- Présenter le catalogue de produits de façon attractive
- Permettre aux clients de commander et payer en ligne sans intervention manuelle
- Simplifier la gestion des commandes et du catalogue pour l'artisane, sans compétences techniques

### 1.3 Statut du projet
*(à préciser)* Application développée bénévolement/en amitié, maintenance assurée dans un premier temps par toi.

---

## 2. Public cible

- **Clients finaux** : particuliers cherchant à commander des mignardises (événements, cadeaux, envies gourmandes) — utilisation mobile principalement.
- **Administratrice (l'artisane)** : gère son catalogue et ses commandes depuis son téléphone, sans connaissances techniques.
- **Support technique (toi)** : accès admin avancé au démarrage pour aider à la prise en main et aux ajustements.

---

## 3. Périmètre fonctionnel

### 3.1 Côté client (vitrine + commande)

| Fonctionnalité | Détail |
|---|---|
| Page d'accueil / à propos | Présentation de l'artisane, son histoire, ses valeurs, photos |
| Catalogue produits | Liste des mignardises avec photo, description, prix, éventuellement allergènes |
| Fiche produit | Détail d'un produit, choix de quantité, options (ex : boîte de 6/12) |
| Panier | Ajout/suppression de produits, récapitulatif, calcul du total |
| Paiement en ligne | Intégration d'une solution de paiement locale ivoirienne (**Wave**, éventuellement Orange Money / MTN MoMo en complément) — voir section 4.2 |
| Compte client | **Obligatoire** pour commander (inscription avec téléphone/email) |
| Suivi de commande | Statut visible : reçue / en préparation / prête / livrée |
| Notifications | Confirmation de commande, changement de statut (via Firebase Cloud Messaging) |
| Mode de retrait | **Retrait en boutique** (gratuit) et **livraison** (payante), tous deux disponibles, avec créneaux |
| Frais de livraison | **Fixés selon la commune** de livraison à Abidjan (grille tarifaire par commune à définir avec l'artisane) |
| Demandes spécifiques | Bouton de redirection vers **WhatsApp Business** pour les demandes particulières (commandes sur-mesure, grandes quantités, questions). Pas de chat intégré en v1 — à réévaluer plus tard si le volume de demandes le justifie |

### 3.2 Côté admin (espace intégré dans l'app)

| Fonctionnalité | Détail |
|---|---|
| Connexion sécurisée | Accès réservé (Firebase Auth), rôle admin distinct des clients |
| Gestion du catalogue | Ajouter / modifier / supprimer un produit, photos, prix, disponibilité |
| Gestion des commandes | Liste des commandes, détail, changement de statut |
| Gestion du stock | Simple bascule **disponible / indisponible** par produit (pas de gestion de quantités précises en v1) |
| Statistiques simples *(optionnel)* | Nombre de commandes, chiffre d'affaires, produits les plus vendus |
| Accès support technique | Toi : accès admin complet pour aide au démarrage |

### 3.3 Hors périmètre (v1)
À lister ensemble — par exemple : programme de fidélité, avis clients, multi-boutiques, livraison via prestataire tiers, etc.

---

## 4. Architecture technique

### 4.1 Stack générale

- **Front-end** : Flutter (une seule base de code pour Android et iOS ; le web pourra être envisagé plus tard si utile)
- **Back-end** : Firebase
  - **Firestore** : base de données (produits, commandes, utilisateurs)
  - **Firebase Auth** : authentification clients et admin (compte obligatoire pour commander)
  - **Cloud Storage** : hébergement des photos produits
  - **Cloud Functions** : logique métier sécurisée (ex : confirmation de paiement, notifications)
  - **Firebase Cloud Messaging (FCM)** : notifications push

### 4.2 Paiement en ligne (Wave / mobile money — Côte d'Ivoire)

**Pas de Stripe** : la clientèle ciblée utilise le mobile money, donc l'intégration se fera avec une solution locale. Deux options possibles, à trancher ensemble :

| Option | Avantages | Contraintes |
|---|---|---|
| **API Wave Business en direct** | Frais marchand les plus bas (~1 %), intégration officielle, webhooks fiables | Nécessite un compte Wave Business au nom de l'artisane (KYC : CNI + justificatif d'activité / registre de commerce), délai d'activation de quelques jours |
| **Agrégateur (CinetPay, PayDunya...)** | Un seul compte pour accepter Wave **et** Orange Money / MTN MoMo en même temps, souvent plus simple à ouvrir pour un petit commerce | Frais légèrement plus élevés (commission de l'agrégateur en plus) |

Fonctionnement technique (dans les deux cas) : le paiement est initié depuis une **Cloud Function** (jamais directement depuis l'app, pour ne pas exposer les clés API) → l'utilisateur est redirigé vers la page/app de paiement → un **webhook** confirme le paiement côté serveur → la commande est validée dans Firestore.

*À trancher ensemble* : vous n'êtes pas encore inscrits au registre de commerce. Les sources sur les exigences exactes de CinetPay divergent : la procédure "standard" demande un RCCM, mais CinetPay propose aussi une offre **"E-Shop"** présentée comme accessible aux **entrepreneurs individuels** pour créer une boutique en ligne et encaisser en mobile money/carte — sans qu'il soit certain qu'elle dispense totalement de justificatif d'activité. La démarche la plus fiable est de contacter directement le support CinetPay (ou PayDunya) pour confirmer ce qu'ils acceptent comme statut pour une activité artisanale non encore enregistrée.

En attendant, deux pistes concrètes :
- **Ouvrir un compte Wave Business "personnel/individuel"** : Wave accepte les indépendants avec juste une CNI dans certains cas (à vérifier auprès de leur service marchand), même si l'accès à l'**API** complète semble réservé aux comptes avec justificatif d'activité.
- **MVP sans paiement automatisé** : la commande passe par l'app (panier + récap), mais le paiement se fait par transfert Wave manuel (numéro affiché ou lien Wave), confirmé ensuite par l'artisane dans son espace admin. Moins fluide, mais permet de lancer l'app tout de suite sans attendre une immatriculation, et de basculer vers l'API dès que le statut administratif le permet.

---

## 5. Rôles et droits d'accès

| Rôle | Droits |
|---|---|
| Client | Consulter le catalogue, commander, payer, suivre ses commandes |
| Admin (artisane) | Gérer catalogue et commandes |
| Admin technique (toi) | Accès complet, y compris configuration technique |

---

## 6. Contraintes

- Budget de développement : bénévole *(à confirmer)*
- Coûts récurrents à prévoir : commission Wave/agrégateur (~1 à 3 % selon l'option choisie), quota Firebase (gratuit dans un premier temps, payant au-delà d'un certain usage)
- Délai souhaité : *(à définir)*
- Design/charte graphique : dominante **blanc et rose**, à affiner avec l'artisane (nuance de rose, logo, typographie, ton visuel — doux/féminin/gourmand)

---

## 6bis. Estimation des coûts récurrents

Frais payés au fur et à mesure, en fonction de l'usage réel. Estimation pour un démarrage à petite échelle :

| Poste | Estimation | Fréquence |
|---|---|---|
| Compte développeur Google Play | ~15 000 FCFA | Paiement unique |
| Compte développeur Apple (si iOS envisagé) | ~60 000 FCFA (~99 $) | Annuel |
| Firebase (Firestore, Auth, Storage, Functions, FCM) | Firestore/Auth/Functions/FCM restent gratuits au démarrage (quota "Spark"). **Storage nécessite désormais le plan Blaze** depuis février 2026 (carte bancaire à lier obligatoirement), mais reste à 0 FCFA tant que l'usage tient dans le tier "Always Free" de Google Cloud (5 Go stockés, 100 Go de sortie/mois en région US) — largement suffisant pour un catalogue de photos produits compressées | Mensuel, au-delà du quota gratuit |
| Commission paiement (Wave direct ou agrégateur) | ~1 % à 2 % du montant de chaque commande (pas de frais fixe mensuel) | Par transaction |
| Nom de domaine (optionnel, si site vitrine web en plus de l'app) | ~10 000–15 000 FCFA | Annuel |

**Point important** : Android seul (sans compte Apple) permet de démarrer avec un budget quasi nul les premiers mois — seul le compte développeur Google Play (~15 000 FCFA, une seule fois) est incontournable pour publier sur le Play Store. iOS peut être ajouté plus tard si le besoin se confirme.

**Point d'attention Firebase Storage** : depuis février 2026, Storage exige le plan Blaze (carte liée obligatoire) même à faible usage — ce n'est plus optionnel comme avant. Ça reste gratuit si on stocke le bucket en région US et qu'on ne dépasse pas 5 Go de photos, mais il faut prévoir de lier une carte bancaire dès la mise en place du projet Firebase (voir section 5 de la spec technique).

---

## 7. Points encore en suspens

1. **Solution de paiement** : à confirmer directement auprès de CinetPay/PayDunya/Wave le statut minimal accepté sans registre de commerce (voir section 4.2). En parallèle, l'option "MVP avec confirmation manuelle du paiement" permet de ne pas bloquer le développement.
2. **Grille tarifaire de livraison par commune** : à établir avec l'artisane (ex : liste des communes couvertes + tarif associé)
3. **Identité visuelle** : pas de logo ni de photos produits pour l'instant → mis de côté pour le moment. En attendant, l'app pourra démarrer avec des placeholders (icônes, couleurs blanc/rose) et être habillée dès que les visuels seront prêts. Une séance photo des mignardises sera nécessaire avant le lancement public.
4. **Délai de lancement** : aucun délai visé — le rythme de développement reste libre.

---

## 8. Étapes suivantes proposées

1. Valider ce cahier des charges avec l'artisane
2. Définir la charte graphique (maquettes Figma ou directement dans Flutter)
3. Modéliser la base de données Firestore (produits, commandes, utilisateurs)
4. Développer la vitrine + catalogue
5. Développer le panier + intégration du paiement (Wave/agrégateur)
6. Développer l'espace admin
7. Tests et mise en production

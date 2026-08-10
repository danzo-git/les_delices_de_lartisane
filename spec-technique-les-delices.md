# Spécification technique — Les Délices de l'Artisane

Document de référence à donner à Antigravity (ou tout assistant de code) en complément du cahier des charges et des maquettes. Il décrit le modèle de données et l'architecture attendue, pour que le code généré reste cohérent d'un écran à l'autre.

---

## 1. Modèle de données Firestore

### Collection `users`
```
users/{uid}
  nom: string
  telephone: string
  email: string
  role: "client" | "admin"
  adresses: [
    { label: string, commune: string, details: string }
  ]
  created_at: timestamp
```

### Collection `categories`
```
categories/{categoryId}
  nom: string              // "Macarons", "Petits fours", "Tartes", "Biscuits", "Coffrets"
  ordre: number             // pour l'ordre d'affichage
  icone: string (optionnel)
```

### Collection `products`
```
products/{productId}
  nom: string
  description: string
  categorie_id: string       // référence vers categories
  image_url: string
  disponible: boolean        // toggle disponible/indisponible (admin)
  ingredients: string
  allergenes: string
  note_moyenne: number       // ex : 4.8
  nombre_avis: number
  options: [                 // ex : Boîte de 6 / 12 / 24
    { label: string, prix: number }
  ]
  created_at: timestamp
```

### Collection `orders`
```
orders/{orderId}
  numero: string              // ex : "2541", affiché à l'écran
  user_id: string
  client_nom: string
  client_telephone: string
  items: [
    {
      product_id: string,
      nom: string,
      option_label: string,   // "Boîte de 6"
      prix_unitaire: number,
      quantite: number,
      sous_total: number
    }
  ]
  sous_total: number
  mode_livraison: "retrait" | "livraison"
  commune: string (si livraison)
  frais_livraison: number
  total: number
  mode_paiement: "wave" | "orange_money" | "mtn_momo"
  statut_paiement: "en_attente" | "confirme" | "echoue"
  statut_commande: "recue" | "en_preparation" | "prete" | "livree"
  historique_statuts: [
    { statut: string, date: timestamp }
  ]
  created_at: timestamp
```

### Collection `delivery_fees` (grille tarifaire par commune)
```
delivery_fees/{communeId}
  commune: string     // "Cocody", "Yopougon", ...
  frais: number
  actif: boolean
```

### Sous-collection `reviews` (optionnel, v2)
```
products/{productId}/reviews/{reviewId}
  user_id: string
  note: number
  commentaire: string
  created_at: timestamp
```

---

## 2. Règles de sécurité Firestore (principe général)

- `users` : chaque utilisateur ne lit/écrit que son propre document ; admin lit tout
- `products`, `categories`, `delivery_fees` : lecture publique, écriture réservée au rôle `admin`
- `orders` : un client ne lit/écrit que ses propres commandes ; admin lit/écrit tout
- Toute logique sensible (validation de paiement, calcul de total) passe par **Cloud Functions**, jamais calculée côté client uniquement

---

## 3. Architecture Flutter

### 3.1 Gestion d'état recommandée
**Riverpod** — bon compromis simplicité/robustesse pour ce type d'app, bien documenté, facile à faire générer par un assistant de code.

### 3.2 Packages principaux
```yaml
dependencies:
  firebase_core:
  firebase_auth:
  cloud_firestore:
  firebase_storage:
  cloud_functions:
  firebase_messaging:
  flutter_riverpod:
  go_router:              # navigation
  google_fonts:           # Poppins
  cached_network_image:   # affichage images produits
  image_picker:           # upload photos côté admin
```

### 3.3 Structure de dossiers
```
lib/
  main.dart
  theme/
    app_theme.dart        # couleurs, typo Poppins, boutons — copie exacte du design system
    app_colors.dart        # #E96A92, #F8AFC6, #FFE9F0, #2C2C2C, #8E8E93, #3CB371
  core/
    router.dart             # go_router, routes client + admin
    widgets/                 # boutons, champs de saisie, badges statut réutilisables
  features/
    auth/
      screens/               # splash, connexion, inscription
      providers/
    catalogue/
      screens/               # accueil, catalogue, fiche produit
      providers/
    panier/
      screens/
      providers/
    commande/
      screens/               # paiement, suivi de commande
      providers/
    profil/
      screens/               # mon compte
      providers/
    admin/
      screens/               # dashboard, produits, commandes
      providers/
  models/
    product.dart
    order.dart
    user_profile.dart
    category.dart
  services/
    firestore_service.dart
    auth_service.dart
    payment_service.dart     # appel Cloud Function de paiement
```

### 3.4 Thème — valeurs exactes du design system
```dart
primaire:        #E96A92
primaire_clair:  #F8AFC6
fond:            #FFE9F0
texte:           #2C2C2C
secondaire:      #8E8E93
succes:          #3CB371
police:          Poppins (Bold / SemiBold / Medium / Regular)
```

---

## 4. Ordre de développement conseillé

Construire écran par écran, dans cet ordre, en donnant à Antigravity **un écran à la fois** avec la maquette correspondante :

1. **Thème global** (`app_theme.dart`) — à faire en tout premier, tous les écrans en dépendent
2. **Auth** : Splash → Connexion → Inscription
3. **Vitrine** : Accueil → Catalogue → Fiche produit
4. **Panier** : Panier → Paiement (mode "confirmation manuelle" au départ, voir cahier des charges §4.2)
5. **Suivi** : Suivi de commande → Mon compte
6. **Admin** : Dashboard → Produits → Commandes

À chaque étape : donner l'écran Figma correspondant + ce document + le modèle de données, faire générer, tester avant de passer au suivant.

---

## 5. Prérequis avant de coder

- [ ] Créer le projet sur [console.firebase.google.com](https://console.firebase.google.com)
- [ ] Activer Authentication (téléphone ou email/mot de passe)
- [ ] Activer Firestore (mode production, règles de sécurité ci-dessus)
- [ ] Activer Storage (photos produits) — **nécessite le plan Blaze depuis février 2026** : lier une carte bancaire est obligatoire pour créer le bucket, même si l'usage reste gratuit ensuite. Choisir une région US (us-central1, us-west1 ou us-east1) pour bénéficier du tier "Always Free" Google Cloud (5 Go stockés, 100 Go de sortie/mois)
- [ ] Activer Cloud Functions (nécessite le plan Blaze — reste gratuit tant que l'usage est faible)
- [ ] Créer un projet Flutter et le connecter à Firebase (`flutterfire configure`)
- [ ] Créer les documents `categories` et `delivery_fees` de base dans Firestore (données de départ)

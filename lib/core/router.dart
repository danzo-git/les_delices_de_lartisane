import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/main/screens/main_screen.dart';
import '../features/catalogue/screens/home_screen.dart';
import '../features/catalogue/screens/catalogue_screen.dart';
import '../features/catalogue/screens/product_detail_screen.dart';
import '../features/profil/screens/profile_screen.dart';
import '../features/panier/screens/panier_screen.dart';
import '../features/commande/screens/order_history_screen.dart';
import '../features/commande/screens/order_tracking_screen.dart';
import '../features/admin/screens/admin_shell.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/admin/screens/admin_orders_screen.dart';
import '../features/admin/screens/admin_products_screen.dart';
import '../core/widgets/coming_soon_screen.dart';
import '../features/auth/providers/auth_provider.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorAccueilKey = GlobalKey<NavigatorState>(debugLabel: 'accueil');
final _shellNavigatorCatalogueKey = GlobalKey<NavigatorState>(debugLabel: 'catalogue');
final _shellNavigatorPanierKey = GlobalKey<NavigatorState>(debugLabel: 'panier');
final _shellNavigatorCompteKey = GlobalKey<NavigatorState>(debugLabel: 'compte');
final _adminNavigatorDashboardKey = GlobalKey<NavigatorState>(debugLabel: 'admin-dashboard');
final _adminNavigatorCommandesKey = GlobalKey<NavigatorState>(debugLabel: 'admin-commandes');
final _adminNavigatorProduitsKey = GlobalKey<NavigatorState>(debugLabel: 'admin-produits');
final _adminNavigatorStatsKey = GlobalKey<NavigatorState>(debugLabel: 'admin-stats');
final _adminNavigatorParamsKey = GlobalKey<NavigatorState>(debugLabel: 'admin-params');

/// Listenable qui notifie GoRouter à chaque changement d'état d'auth
class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(this._ref) {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }

  final Ref _ref;

  bool get isAdmin {
    final profile = _ref.read(authProvider).profile;
    return profile?.role == 'admin';
  }
}

/// Provider du routeur — dépend de authProvider pour la protection des routes
final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthStateListenable(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: listenable,
    redirect: (context, state) {
      final isAdmin = listenable.isAdmin;
      final isAdminRoute = state.matchedLocation.startsWith('/admin');

      // Si une route /admin est demandée sans être admin → accueil client
      if (isAdminRoute && !isAdmin) {
        return '/home';
      }
      return null;
    },
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

      // ── ESPACE CLIENT ──────────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorAccueilKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorCatalogueKey,
            routes: [
              GoRoute(
                path: '/catalogue',
                builder: (context, state) => const CatalogueScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorPanierKey,
            routes: [
              GoRoute(
                path: '/panier',
                builder: (context, state) => const PanierScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorCompteKey,
            routes: [
              GoRoute(
                path: '/compte',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Routes client hors bottom nav
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/product/:id',
        builder: (context, state) {
          final productId = state.pathParameters['id']!;
          return ProductDetailScreen(productId: productId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/orders',
        builder: (context, state) => const OrderHistoryScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/order/:id',
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          return OrderTrackingScreen(orderId: orderId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/coming-soon',
        builder: (context, state) => const ComingSoonScreen(),
      ),

      // ── ESPACE ADMIN ───────────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdminShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _adminNavigatorDashboardKey,
            routes: [
              GoRoute(
                path: '/admin',
                builder: (context, state) => const AdminDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _adminNavigatorCommandesKey,
            routes: [
              GoRoute(
                path: '/admin/commandes',
                builder: (context, state) => const AdminOrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _adminNavigatorProduitsKey,
            routes: [
              GoRoute(
                path: '/admin/produits',
                builder: (context, state) => const AdminProductsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _adminNavigatorStatsKey,
            routes: [
              GoRoute(
                path: '/admin/statistiques',
                builder: (context, state) => const ComingSoonScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _adminNavigatorParamsKey,
            routes: [
              GoRoute(
                path: '/admin/parametres',
                builder: (context, state) => const ComingSoonScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

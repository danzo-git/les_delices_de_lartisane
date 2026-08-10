import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/main/screens/main_screen.dart';
import '../features/catalogue/screens/home_screen.dart';
import '../features/catalogue/screens/catalogue_screen.dart';
import '../features/catalogue/screens/product_detail_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorAccueilKey = GlobalKey<NavigatorState>(debugLabel: 'accueil');
final _shellNavigatorCatalogueKey = GlobalKey<NavigatorState>(debugLabel: 'catalogue');
final _shellNavigatorPanierKey = GlobalKey<NavigatorState>(debugLabel: 'panier');
final _shellNavigatorCompteKey = GlobalKey<NavigatorState>(debugLabel: 'compte');

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
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
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Panier (À venir)')),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorCompteKey,
          routes: [
            GoRoute(
              path: '/compte',
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Compte (À venir)')),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey, // Hide bottom nav bar
      path: '/product/:id',
      builder: (context, state) {
        final productId = state.pathParameters['id']!;
        return ProductDetailScreen(productId: productId);
      },
    ),
  ],
);

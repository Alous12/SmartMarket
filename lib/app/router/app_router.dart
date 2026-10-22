import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assistant/presentation/screens/assistant_screen.dart';
import '../../features/store_navigation/presentation/screens/supermarket_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoginRoute = state.matchedLocation == '/login';
      final isAuthRoute = isLoginRoute || state.matchedLocation == '/register';
      if (authState.isLoading) {
        return isAuthRoute ? null : '/login';
      }

      final isAuthenticated = authState.asData?.value != null;
      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/supermercado';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/supermercado',
        name: 'supermarket',
        builder: (context, state) => const SupermarketScreen(),
      ),
      GoRoute(
        path: '/usuarios',
        name: 'users',
        builder: (context, state) => const UsersScreen(),
      ),
      GoRoute(
        path: '/asistente',
        name: 'assistant',
        builder: (context, state) => const AssistantScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

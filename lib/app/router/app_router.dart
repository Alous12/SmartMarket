import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/assistant/presentation/screens/assistant_screen.dart';
import '../../features/staff/presentation/screens/staff_screen.dart';
import '../../features/store_navigation/presentation/screens/supermarket_screen.dart';
import '../../features/users/presentation/screens/users_screen.dart';

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

      final session = authState.asData?.value;
      final isAuthenticated = session != null;
      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) {
        return session.isAdmin ? '/trabajador' : '/supermercado';
      }
      final isStaffRoute =
          state.matchedLocation == '/trabajador' ||
          state.matchedLocation == '/usuarios';
      if (isStaffRoute && !(session?.isAdmin ?? false)) return '/supermercado';
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
        path: '/trabajador',
        name: 'staff',
        builder: (context, state) => const StaffScreen(),
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

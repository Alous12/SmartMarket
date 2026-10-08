import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/store_navigation/presentation/screens/supermarket_screen.dart';
import '../../features/users/presentation/screens/users_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/supermercado',
    routes: [
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
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

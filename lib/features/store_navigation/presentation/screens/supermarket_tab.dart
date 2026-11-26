import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import 'store_layout_screen.dart';
import 'supermarket_screen.dart';

/// Pestaña Supermercados: el cliente ve el mapa 3D para armar su ruta; el
/// admin, el plano 2D de su sucursal para acomodar los productos (el mapa 3D
/// sigue disponible desde su menú y para seguir una ruta).
class SupermarketTab extends ConsumerWidget {
  const SupermarketTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(
      authControllerProvider.select(
        (state) => state.asData?.value?.isAdmin ?? false,
      ),
    );
    return isAdmin ? const StoreLayoutScreen() : const SupermarketScreen();
  }
}

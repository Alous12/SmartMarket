import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Barra inferior de la app. Cada pestaña conserva su estado al cambiar de una
/// a otra, incluido el mapa 3D, que se pausa mientras no se ve.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  /// Posición de Supermercados, la pestaña inicial, en las ramas del router.
  static const supermarketBranch = 2;

  static const _barHeight = 80.0;

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final current = navigationShell.currentIndex;
    final media = MediaQuery.of(context);
    // El teclado tapa la barra: a las pantallas solo les afecta lo que sobresale.
    final keyboardAboveBar =
        media.viewInsets.bottom - _barHeight - media.padding.bottom;
    return PopScope<Object?>(
      // Siempre bloqueado: si no, Android cierra la app sin consultar a Flutter.
      // Atrás vuelve a Supermercados, y allí el mapa confirma la salida.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && current != supermarketBranch) {
          navigationShell.goBranch(supermarketBranch);
        }
      },
      child: Scaffold(
        // Con el alto fijo, el teclado no redimensiona el visor 3D oculto.
        resizeToAvoidBottomInset: false,
        body: MediaQuery(
          // La barra ya reserva el margen inferior del sistema.
          data: media
              .removePadding(removeBottom: true)
              .copyWith(
                viewInsets: media.viewInsets.copyWith(
                  bottom: keyboardAboveBar > 0 ? keyboardAboveBar : 0,
                ),
              ),
          child: navigationShell,
        ),
        bottomNavigationBar: NavigationBar(
          height: _barHeight,
          selectedIndex: current,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == current,
          ),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'Asistente',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Productos',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Supermercados',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

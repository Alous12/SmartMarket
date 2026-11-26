import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// Barra inferior de la app. Cada pestaña conserva su estado al cambiar de una
/// a otra, incluido el mapa 3D, que se pausa mientras no se ve.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  /// Posición de Supermercados, la pestaña inicial, en las ramas del router.
  static const supermarketBranch = 2;

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  static const _barHeight = 80.0;

  /// Fundido del contenido al cambiar de pestaña. El shell no se reconstruye
  /// ni se desmonta: solo cambia la opacidad de lo que ya está montado.
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );

  @override
  void didUpdateWidget(MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = widget.navigationShell.currentIndex;
    if (index == oldWidget.navigationShell.currentIndex) return;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // El mapa 3D (WebView) aparece sin fundido.
    if (still || index == MainShell.supermarketBranch) {
      _fade.value = 1;
    } else {
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
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
        if (!didPop && current != MainShell.supermarketBranch) {
          navigationShell.goBranch(MainShell.supermarketBranch);
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
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
            child: navigationShell,
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: NavigationBar(
            height: _barHeight,
            selectedIndex: current,
            animationDuration: AppTheme.motion(context, AppTheme.slow),
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == current,
            ),
            destinations: [
              for (final (index, (outlined, filled, label)) in const [
                (Icons.auto_awesome_outlined, Icons.auto_awesome, 'Asistente'),
                (Icons.inventory_2_outlined, Icons.inventory_2, 'Productos'),
                (Icons.storefront_outlined, Icons.storefront, 'Supermercados'),
                (Icons.person_outline, Icons.person, 'Perfil'),
              ].indexed)
                NavigationDestination(
                  // El mismo widget en ambos estados: así el icono cambia de
                  // contorno a relleno con una transición.
                  icon: _NavIcon(
                    outlined: outlined,
                    filled: filled,
                    selected: index == current,
                  ),
                  selectedIcon: _NavIcon(
                    outlined: outlined,
                    filled: filled,
                    selected: index == current,
                  ),
                  label: label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.outlined,
    required this.filled,
    required this.selected,
  });

  final IconData outlined;
  final IconData filled;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppTheme.motion(context, AppTheme.medium),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.8, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: Icon(
        selected ? filled : outlined,
        key: ValueKey(selected),
        color: selected ? AppTheme.ink : AppTheme.muted,
      ),
    );
  }
}

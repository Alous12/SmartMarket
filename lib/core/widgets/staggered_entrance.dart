import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Entrada escalonada de un elemento de lista: aparece y sube 8 px. Solo los
/// primeros [maxAnimated] elementos se animan; el resto aparece directo.
///
/// Solo se anima cuando la lista aparece: si el elemento vuelve a entrar en
/// pantalla mientras se desplaza, se muestra sin animación. La animación usa
/// transiciones compuestas (sin reconstruir el contenido en cada cuadro).
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.maxAnimated = 8,
  });

  final int index;
  final Widget child;
  final int maxAnimated;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  static const _step = Duration(milliseconds: 40);
  static const _duration = Duration(milliseconds: 260);

  AnimationController? _controller;
  Animation<double>? _opacity;
  Animation<Offset>? _offset;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null || !_shouldAnimate()) return;
    final delay = _step * widget.index;
    final total = delay + _duration;
    final start = delay.inMicroseconds / total.inMicroseconds;
    final controller = AnimationController(vsync: this, duration: total);
    final curve = CurvedAnimation(
      parent: controller,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );
    _controller = controller;
    _opacity = curve;
    _offset = Tween(begin: const Offset(0, 8), end: Offset.zero).animate(curve);
    controller.forward();
  }

  bool _shouldAnimate() {
    if (widget.index >= widget.maxAnimated) return false;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return false;
    // Si la lista ya se está desplazando, el elemento entra sin animación.
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null) return true;
    return !position.isScrollingNotifier.value && position.pixels < 1;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = _opacity, offset = _offset;
    if (opacity == null || offset == null) return widget.child;
    return FadeTransition(
      opacity: opacity,
      child: AnimatedBuilder(
        animation: offset,
        builder: (context, child) =>
            Transform.translate(offset: offset.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// Cambio animado entre dos contenidos: fade y un desplazamiento corto.
class SmSwitcher extends StatelessWidget {
  const SmSwitcher({
    super.key,
    required this.child,
    this.duration = AppTheme.medium,
    this.offset = const Offset(0, 0.04),
    this.size = false,
  });

  final Widget child;
  final Duration duration;
  final Offset offset;

  /// Anima también el alto, para contenidos de distinto tamaño.
  final bool size;

  @override
  Widget build(BuildContext context) {
    final switcher = AnimatedSwitcher(
      duration: AppTheme.motion(context, duration),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: offset, end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
    if (!size) return switcher;
    return AnimatedSize(
      duration: AppTheme.motion(context, duration),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: switcher,
    );
  }
}

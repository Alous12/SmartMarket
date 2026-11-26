import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fila con desplazamiento horizontal que responde al dedo, al arrastre con
/// mouse y a la rueda o el trackpad (el gesto vertical mueve la fila).
///
/// Si hay contenido oculto, el borde se desvanece y aparece una flecha que
/// avanza la fila al tocarla, así nunca depende solo del gesto de deslizar.
class HorizontalScrollRow extends StatefulWidget {
  const HorizontalScrollRow({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.arrows = true,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  /// Muestra las flechas para avanzar y retroceder.
  final bool arrows;

  @override
  State<HorizontalScrollRow> createState() => _HorizontalScrollRowState();
}

class _HorizontalScrollRowState extends State<HorizontalScrollRow> {
  final _controller = ScrollController();
  bool _canBack = false;
  bool _canForward = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateEdges);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateEdges());
  }

  @override
  void didUpdateWidget(HorizontalScrollRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateEdges());
  }

  @override
  void dispose() {
    _controller.removeListener(_updateEdges);
    _controller.dispose();
    super.dispose();
  }

  void _updateEdges() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    if (!position.hasContentDimensions) return;
    final back = position.pixels > position.minScrollExtent + 1;
    final forward = position.pixels < position.maxScrollExtent - 1;
    if (back != _canBack || forward != _canForward) {
      setState(() {
        _canBack = back;
        _canForward = forward;
      });
    }
  }

  /// Avanza o retrocede casi un ancho de la fila.
  void _page(int direction) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final target =
        (position.pixels + direction * position.viewportDimension * 0.75).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    final duration = AppTheme.motion(context, AppTheme.slow);
    if (duration == Duration.zero) {
      _controller.jumpTo(target);
    } else {
      _controller.animateTo(
        target,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) return;
    final delta = event.scrollDelta;
    // Solo se adueña del gesto si es sobre todo vertical: el horizontal ya lo
    // atiende la propia lista.
    if (delta.dy.abs() <= delta.dx.abs()) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final position = _controller.position;
      final target =
          (position.pixels + (event as PointerScrollEvent).scrollDelta.dy)
              .clamp(position.minScrollExtent, position.maxScrollExtent);
      if (target != position.pixels) _controller.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    final list = Listener(
      onPointerSignal: _onPointerSignal,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(
          context,
        ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) {
            _updateEdges();
            return false;
          },
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: widget.padding,
            child: Row(children: widget.children),
          ),
        ),
      ),
    );
    if (!widget.arrows) return list;
    return Stack(
      children: [
        Positioned.fill(child: list),
        if (_canBack)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _Edge(
              background: background,
              forward: false,
              onTap: () => _page(-1),
            ),
          ),
        if (_canForward)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _Edge(
              background: background,
              forward: true,
              onTap: () => _page(1),
            ),
          ),
      ],
    );
  }
}

/// Borde desvanecido con una flecha para avanzar o retroceder la fila.
class _Edge extends StatelessWidget {
  const _Edge({
    required this.background,
    required this.forward,
    required this.onTap,
  });

  final Color background;
  final bool forward;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: forward ? Alignment.centerLeft : Alignment.centerRight,
          end: forward ? Alignment.centerRight : Alignment.centerLeft,
          colors: [background.withValues(alpha: 0), background],
          stops: const [0, 0.55],
        ),
      ),
      alignment: forward ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: forward ? 'Ver más' : 'Ver anteriores',
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(
            side: BorderSide(color: AppTheme.border, width: 1.5),
          ),
          elevation: 2,
          shadowColor: Colors.black26,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                forward
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                color: AppTheme.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

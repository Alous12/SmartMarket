import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Fila con desplazamiento horizontal que se mueve con el dedo. También
/// responde al arrastre con mouse y a la rueda o el trackpad (el gesto
/// vertical mueve la fila).
class HorizontalScrollRow extends StatefulWidget {
  const HorizontalScrollRow({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  State<HorizontalScrollRow> createState() => _HorizontalScrollRowState();
}

class _HorizontalScrollRowState extends State<HorizontalScrollRow> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(
          context,
        ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
        child: SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: widget.padding,
          child: Row(children: widget.children),
        ),
      ),
    );
  }
}

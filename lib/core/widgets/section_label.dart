import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rótulo de sección en mayúsculas: separa grupos dentro de una pantalla u hoja.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color = AppTheme.muted});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

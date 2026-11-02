import 'package:flutter/material.dart';

class BottomAction extends StatelessWidget {
  const BottomAction({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: SafeArea(
        top: false,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }
}

Future<bool> confirmExit(BuildContext context) async {
  final exit = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Salir de SmartMarket?'),
      content: const Text('Puedes seguir explorando el supermercado.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Seguir explorando'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Salir'),
        ),
      ],
    ),
  );
  return exit == true;
}

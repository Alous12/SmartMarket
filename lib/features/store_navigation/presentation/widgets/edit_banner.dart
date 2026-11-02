import 'package:flutter/material.dart';

import '../../domain/entities/store_model.dart';

class EditBanner extends StatelessWidget {
  const EditBanner({
    super.key,
    required this.carrying,
    required this.busy,
    required this.onDropCarry,
    required this.onFinish,
  });

  final StoreProduct? carrying;
  final bool busy;
  final VoidCallback onDropCarry;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final text = busy
        ? 'El avatar va en camino…'
        : carrying == null
        ? 'Modo edición: toca una caja o un espacio verde.'
        : 'Llevas "${carrying!.name}". Toca otro espacio para dejarlo.';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            const Icon(Icons.edit_location_alt_outlined),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
            if (carrying != null && !busy)
              TextButton(onPressed: onDropCarry, child: const Text('Soltar')),
            FilledButton(onPressed: onFinish, child: const Text('Terminar')),
          ],
        ),
      ),
    );
  }
}

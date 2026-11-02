import 'package:flutter/material.dart';

import '../../domain/entities/store_model.dart';
import '../../domain/services/store_route_planner.dart';

class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({
    super.key,
    required this.plan,
    required this.nameOf,
    required this.onClear,
  });

  final StoreRoutePlan plan;
  final String Function(StoreProduct product) nameOf;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        child: Row(
          children: [
            Icon(Icons.route, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${plan.products.length} paradas · '
                '${plan.distance.toStringAsFixed(1)} unidades · '
                '${plan.products.take(2).map(nameOf).join(', ')}'
                '${plan.products.length > 2 ? '…' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            IconButton(
              tooltip: 'Quitar ruta',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

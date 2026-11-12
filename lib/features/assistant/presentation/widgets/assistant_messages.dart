import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/assistant_request.dart';
import '../../domain/entities/recipe_availability.dart';
import '../providers/assistant_chat_provider.dart';

const _warning = Color(0xFFB26A00);
const _warningTint = Color(0xFFFFF6E5);
const _hint = TextStyle(color: AppTheme.muted, fontSize: 14);

/// Burbuja con la petición enviada por el usuario.
class UserMessage extends StatelessWidget {
  const UserMessage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: const BoxDecoration(
            color: AppTheme.lime,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(color: AppTheme.ink, fontSize: 17),
          ),
        ),
      ),
    );
  }
}

/// Respuesta del asistente: progreso, receta con el resumen de su disponibilidad
/// o el motivo por el que no se pudo atender la petición.
class AssistantReply extends StatelessWidget {
  const AssistantReply({
    super.key,
    required this.entry,
    required this.currentBranchId,
    required this.onRetryAvailability,
    required this.onRetryPolling,
    required this.onShowRoute,
    required this.onSelectProduct,
    required this.selectingProduct,
    required this.onExcludeIngredient,
  });

  final AssistantChatEntry entry;

  /// Supermercado abierto en el mapa.
  final int? currentBranchId;
  final VoidCallback onRetryAvailability;
  final VoidCallback onRetryPolling;
  final ValueChanged<ShoppingRoute> onShowRoute;
  final void Function(int, IngredientProductOption) onSelectProduct;
  final bool selectingProduct;
  final void Function(int, bool) onExcludeIngredient;

  @override
  Widget build(BuildContext context) {
    final request = entry.request;
    final recipeName = request.recipeName;
    final Widget content = switch (request.status) {
      AssistantRequestStatus.received || AssistantRequestStatus.processing =>
        entry.pollingFailed
            ? Row(
                children: [
                  const Expanded(
                    child: Text(
                      'No se pudo consultar el avance. La petición podría seguir procesándose.',
                      style: _hint,
                    ),
                  ),
                  TextButton(
                    onPressed: onRetryPolling,
                    child: const Text('Reintentar'),
                  ),
                ],
              )
            : _Progress(
                text: recipeName == null
                    ? 'Identificando la receta…'
                    : 'Preparando la lista de $recipeName…',
              ),
      AssistantRequestStatus.completed => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            recipeName ?? 'Receta',
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          _IngredientList(ingredients: request.ingredients),
          const SizedBox(height: 6),
          _AvailabilitySummary(
            entry: entry,
            currentBranchId: currentBranchId,
            onRetry: onRetryAvailability,
            onShowRoute: onShowRoute,
            onSelectProduct: onSelectProduct,
            selectingProduct: selectingProduct,
            onExcludeIngredient: onExcludeIngredient,
          ),
        ],
      ),
      AssistantRequestStatus.rejected || AssistantRequestStatus.failed => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppTheme.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              request.message ?? 'No se pudo procesar tu petición.',
              style: const TextStyle(color: AppTheme.ink, fontSize: 16),
            ),
          ),
        ],
      ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AssistantAvatar(),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border.fromBorderSide(BorderSide(color: AppTheme.border)),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: content,
          ),
        ),
      ],
    );
  }
}

class AssistantAvatar extends StatelessWidget {
  const AssistantAvatar({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppTheme.tint,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.auto_awesome, size: size * 0.55, color: AppTheme.green),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.green,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: AppTheme.muted, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

/// Lista de ingredientes plegada: el resumen es lo primero que se lee.
class _IngredientList extends StatelessWidget {
  const _IngredientList({required this.ingredients});

  final List<AssistantIngredient> ingredients;

  static String _quantity(AssistantIngredient ingredient) {
    final quantity = ingredient.quantity;
    if (quantity == null) return 'al gusto';
    final amount = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();
    return [amount, ?ingredient.unit].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 6),
      dense: true,
      visualDensity: VisualDensity.compact,
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: AppTheme.muted,
      collapsedIconColor: AppTheme.muted,
      title: Text('Ingredientes (${ingredients.length})', style: _hint),
      children: [
        for (final ingredient in ingredients)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ', style: TextStyle(color: AppTheme.green)),
                Expanded(
                  child: Text(
                    ingredient.name,
                    style: const TextStyle(color: AppTheme.ink, fontSize: 16),
                  ),
                ),
                Text(
                  _quantity(ingredient),
                  style: const TextStyle(color: AppTheme.muted, fontSize: 15),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Resumen de la lista: dónde comprar y qué no hay en ningún supermercado.
class _AvailabilitySummary extends StatelessWidget {
  const _AvailabilitySummary({
    required this.entry,
    required this.currentBranchId,
    required this.onRetry,
    required this.onShowRoute,
    required this.onSelectProduct,
    required this.selectingProduct,
    required this.onExcludeIngredient,
  });

  final AssistantChatEntry entry;
  final int? currentBranchId;
  final VoidCallback onRetry;
  final ValueChanged<ShoppingRoute> onShowRoute;
  final void Function(int, IngredientProductOption) onSelectProduct;
  final bool selectingProduct;
  final void Function(int, bool) onExcludeIngredient;

  @override
  Widget build(BuildContext context) {
    final availability = entry.availability;
    if (entry.availabilityFailed) {
      return Row(
        children: [
          const Expanded(
            child: Text('No se pudo consultar el inventario.', style: _hint),
          ),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      );
    }
    if (availability == null) {
      return const _Progress(text: 'Consultando el inventario…');
    }

    if (availability.items.any(
      (item) => item.productOptions.isNotEmpty || item.excluded,
    )) {
      return Material(
        color: Colors.transparent,
        child: _ProductPlanner(
          requestId: entry.request.id,
          availability: availability,
          busy: selectingProduct,
          onSelectProduct: onSelectProduct,
          onExcludeIngredient: onExcludeIngredient,
          onShowRoute: onShowRoute,
        ),
      );
    }

    final options = availability.options;
    final nowhere = availability.nowhere;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryBanner(
          text: availability.summaryFor(currentBranchId),
          positive: availability.hasFullRoute,
        ),
        if (nowhere.isNotEmpty) ...[
          const SizedBox(height: 10),
          _MissingProducts(items: nowhere),
        ],
        if (options.length == 1) ...[
          for (final detail in availability.detailsFor(options.single))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(detail, style: _hint),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => onShowRoute(options.single),
            icon: const Icon(Icons.route),
            label: const Text('Mostrar ruta'),
          ),
        ] else
          for (final route in options)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _BranchOption(
                route: route,
                details: availability.detailsFor(route),
                onTap: () => onShowRoute(route),
              ),
            ),
      ],
    );
  }
}

class _ProductPlanner extends StatefulWidget {
  const _ProductPlanner({
    required this.requestId,
    required this.availability,
    required this.busy,
    required this.onSelectProduct,
    required this.onExcludeIngredient,
    required this.onShowRoute,
  });

  final int requestId;
  final RecipeAvailability availability;
  final bool busy;
  final void Function(int, IngredientProductOption) onSelectProduct;
  final void Function(int, bool) onExcludeIngredient;
  final ValueChanged<ShoppingRoute> onShowRoute;

  @override
  State<_ProductPlanner> createState() => _ProductPlannerState();
}

class _ProductPlannerState extends State<_ProductPlanner> {
  int? _branchId;

  @override
  Widget build(BuildContext context) {
    final availability = widget.availability;
    final branches = <int, String>{
      for (final route in availability.routes) route.branchId: route.branchName,
      for (final item in availability.items)
        for (final option in item.productOptions)
          option.branchId: option.branchName,
    };
    final branchId = branches.containsKey(_branchId)
        ? _branchId
        : availability.routes.firstOrNull?.branchId ??
              branches.keys.firstOrNull;
    final route = availability.routes
        .where((route) => route.branchId == branchId)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (branchId != null) ...[
          const Text('Supermercado sugerido', style: _hint),
          DropdownButton<int>(
            isExpanded: true,
            value: branchId,
            items: [
              for (final branch in branches.entries)
                DropdownMenuItem(value: branch.key, child: Text(branch.value)),
            ],
            onChanged: widget.busy
                ? null
                : (value) => setState(() => _branchId = value),
          ),
          if (route != null)
            Text(
              '${route.stops.length} ingredientes seleccionados',
              style: _hint,
            ),
        ],
        const Text(
          'Revisa los productos y sus etiquetas: sus atributos no están verificados.',
          style: _hint,
        ),
        ExpansionTile(
          key: PageStorageKey('products-${widget.requestId}'),
          tilePadding: EdgeInsets.zero,
          title: const Text('Revisar productos'),
          subtitle: const Text(
            'Cambia o quita ingredientes de la compra',
            style: _hint,
          ),
          children: [
            for (final item in availability.items)
              Builder(
                builder: (context) {
                  final options = item.productOptions
                      .where((option) => option.branchId == branchId)
                      .toList();
                  final selectedId = route?.stops
                      .where((stop) => stop.itemId == item.itemId)
                      .firstOrNull
                      ?.productId;
                  final selected = options
                      .where((option) => option.productId == selectedId)
                      .firstOrNull;
                  return ExpansionTile(
                    key: PageStorageKey(
                      'product-${widget.requestId}-${item.itemId}',
                    ),
                    tilePadding: EdgeInsets.zero,
                    leading: Checkbox(
                      value: !item.excluded,
                      onChanged: widget.busy
                          ? null
                          : (value) => widget.onExcludeIngredient(
                              item.itemId,
                              value != true,
                            ),
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      item.excluded
                          ? 'Excluido de la compra'
                          : selected == null
                          ? options.isEmpty
                                ? 'Sin producto disponible en esta sucursal'
                                : 'Sin sugerencia: revisa las opciones'
                          : '${selected.name} · ${selected.price.toStringAsFixed(2)} · ${selected.unit}',
                      style: _hint,
                    ),
                    children: [
                      for (final option in options)
                        ListTile(
                          dense: true,
                          title: Text(option.name),
                          subtitle: Text(
                            '${option.price.toStringAsFixed(2)} · ${option.unit}'
                            '${option.isSubstitute ? ' · Reemplazo: ${option.ingredientName}' : ''}',
                          ),
                          trailing:
                              !item.excluded && option.productId == selectedId
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppTheme.green,
                                )
                              : const Icon(Icons.radio_button_unchecked),
                          onTap: widget.busy
                              ? null
                              : () {
                                  if (!item.excluded &&
                                      option.productId == selectedId) {
                                    widget.onExcludeIngredient(
                                      item.itemId,
                                      true,
                                    );
                                  } else {
                                    widget.onSelectProduct(item.itemId, option);
                                  }
                                },
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
        if (route != null && route.missing.isNotEmpty)
          Text('Sin seleccionar: ${route.missing.join(', ')}', style: _hint),
        if (route != null) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: widget.busy ? null : () => widget.onShowRoute(route),
            icon: const Icon(Icons.route),
            label: const Text('Mostrar ruta'),
          ),
        ],
      ],
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.text, required this.positive});

  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppTheme.green : _warning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: positive ? AppTheme.tint : _warningTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            positive ? Icons.check_circle : Icons.info_outline,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ingredientes que no hay en ningún supermercado, con sus reemplazos.
class _MissingProducts extends StatelessWidget {
  const _MissingProducts({required this.items});

  final List<IngredientAvailability> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'No hay en ningún supermercado',
          style: TextStyle(
            color: AppTheme.ink,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(color: AppTheme.ink, fontSize: 15),
                ),
                if (item.substitutes.isEmpty)
                  const Text('Sin reemplazo disponible', style: _hint)
                else
                  for (final substitute in item.substitutes)
                    Text(
                      'Reemplazo: ${substitute.productName} '
                      'en ${substitute.branchName}',
                      style: _hint,
                    ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Supermercado que el usuario puede elegir para hacer su compra.
class _BranchOption extends StatelessWidget {
  const _BranchOption({
    required this.route,
    required this.details,
    required this.onTap,
  });

  final ShoppingRoute route;
  final List<String> details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(14));
    return Material(
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.storefront, size: 22, color: AppTheme.green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.branchName,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    for (final detail in details) Text(detail, style: _hint),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}

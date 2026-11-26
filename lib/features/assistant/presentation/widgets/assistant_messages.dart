import 'package:flutter/material.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_or_error_state.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../domain/entities/assistant_request.dart';
import '../../domain/entities/recipe_availability.dart';
import '../providers/assistant_chat_provider.dart';
import 'product_choice_sheet.dart';
import 'shopping_plan.dart';

const _hint = TextStyle(color: AppTheme.muted, fontSize: 15, height: 1.35);

/// Burbuja con la petición enviada: verde para clientes, `night` para el admin.
class UserMessage extends StatelessWidget {
  const UserMessage({super.key, required this.text, this.admin = false});

  final String text;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.74,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(
            color: admin ? AppTheme.night : AppTheme.green,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// Respuesta del asistente: pasos del análisis, receta con su disponibilidad,
/// respuesta del admin con barras de stock, o el motivo de un rechazo.
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
    this.onOpenList,
    this.onShowRowsInMap,
    this.onUpdateStock,
    this.admin = false,
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

  /// «Ver lista de compras»: abre la lista completa de la receta.
  final VoidCallback? onOpenList;

  /// Respuestas del admin: ver los productos en el mapa o ir a editar stock.
  final ValueChanged<List<AdminAnswerRow>>? onShowRowsInMap;
  final VoidCallback? onUpdateStock;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    final request = entry.request;
    final recipeName = request.recipeName;
    final String stateKey;
    final Widget content;
    switch (request.status) {
      case AssistantRequestStatus.received || AssistantRequestStatus.processing:
        if (entry.pollingFailed) {
          stateKey = 'polling-failed';
          content = EmptyOrErrorState(
            compact: true,
            icon: Icons.wifi_off_rounded,
            title:
                'No se pudo consultar el avance. La petición podría seguir procesándose.',
            onRetry: onRetryPolling,
          );
        } else {
          stateKey = admin ? 'admin-processing' : 'processing';
          content = _Steps(
            title: admin ? 'Consultando inventario' : recipeName ?? 'Analizando tu plato',
            steps: admin
                ? const [
                    _Step('Entendiendo tu consulta…', _StepState.running),
                    _Step('Consultando existencias reales', _StepState.pending),
                  ]
                : [
                    recipeName == null
                        ? const _Step('Identificando la receta…', _StepState.running)
                        : const _Step('Receta reconocida', _StepState.done),
                    if (recipeName != null)
                      _Step(
                        'Preparando la lista de $recipeName…',
                        _StepState.running,
                      ),
                    const _Step('Consultar el inventario', _StepState.pending),
                  ],
            progress: admin ? 0.35 : recipeName == null ? 0.18 : 0.42,
            showOpenList: !admin,
          );
        }
      case AssistantRequestStatus.completed when request.isGeneralAnswer:
        stateKey = 'answer';
        content = _AdminAnswer(
          request: request,
          onShowInMap: onShowRowsInMap,
          onUpdateStock: onUpdateStock,
        );
      case AssistantRequestStatus.completed:
        stateKey = 'completed';
        content = _RecipeResult(
          entry: entry,
          currentBranchId: currentBranchId,
          onRetry: onRetryAvailability,
          onShowRoute: onShowRoute,
          onSelectProduct: onSelectProduct,
          selectingProduct: selectingProduct,
          onExcludeIngredient: onExcludeIngredient,
          onOpenList: onOpenList,
        );
      case AssistantRequestStatus.rejected || AssistantRequestStatus.failed:
        stateKey = 'ended';
        content = EmptyOrErrorState(
          compact: true,
          error: request.status == AssistantRequestStatus.failed,
          icon: request.status == AssistantRequestStatus.failed
              ? Icons.error_outline
              : Icons.info_outline,
          title: request.message ?? 'No se pudo procesar tu petición.',
        );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: request.isGeneralAnswer
              ? double.infinity
              : MediaQuery.sizeOf(context).width * 0.9,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppTheme.border, width: 1.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          ),
          child: SmSwitcher(
            size: true,
            child: KeyedSubtree(key: ValueKey(stateKey), child: content),
          ),
        ),
      ),
    );
  }
}

/// Cuadro lima con destellos: identidad del asistente.
class AssistantAvatar extends StatelessWidget {
  const AssistantAvatar({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.lime,
          borderRadius: BorderRadius.circular(size * 0.27),
        ),
        child: Icon(
          Icons.auto_awesome_outlined,
          size: size * 0.42,
          color: AppTheme.ink,
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AssistantAvatar(),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}

enum _StepState { pending, running, done }

class _Step {
  const _Step(this.text, this.state);

  final String text;
  final _StepState state;
}

/// Pasos del análisis con su estado y una barra gruesa de progreso.
class _Steps extends StatelessWidget {
  const _Steps({
    required this.title,
    required this.steps,
    required this.progress,
    this.showOpenList = true,
  });

  final String title;
  final List<_Step> steps;
  final double progress;
  final bool showOpenList;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _CardTitle(title),
        const SizedBox(height: 14),
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _StepRow(text: step.text, state: step.state),
          ),
        const SizedBox(height: 12),
        _ProgressBar(value: progress),
        if (showOpenList) ...[
          const SizedBox(height: 18),
          // La lista se abre cuando el inventario termina de revisarse.
          const _OpenListButton(onPressed: null),
        ],
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Progreso',
      value: '${(value * 100).round()} %',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: AppTheme.motion(context, AppTheme.slow),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: v,
            minHeight: 10,
            color: AppTheme.green,
            backgroundColor: AppTheme.track,
          ),
        ),
      ),
    );
  }
}

class _OpenListButton extends StatelessWidget {
  const _OpenListButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
      child: const Text('Ver lista de compras'),
    );
  }
}

/// Un paso: pendiente (anillo), en curso (spinner) o hecho (check verde).
class _StepRow extends StatelessWidget {
  const _StepRow({required this.text, required this.state, this.trailing});

  final String text;
  final _StepState state;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Widget icon = switch (state) {
      _StepState.pending => Container(
        key: const ValueKey('pending'),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.track, width: 3),
        ),
      ),
      _StepState.running => const SizedBox(
        key: ValueKey('running'),
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: AppTheme.green,
          backgroundColor: AppTheme.track,
        ),
      ),
      _StepState.done => const Icon(
        Icons.check_rounded,
        key: ValueKey('done'),
        size: 26,
        color: AppTheme.green,
      ),
    };
    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Center(
            child: AnimatedSwitcher(
              duration: AppTheme.motion(context, AppTheme.medium),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                ),
                child: child,
              ),
              child: icon,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: state == _StepState.done ? AppTheme.ink : AppTheme.muted,
              fontSize: 18,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Receta lista: pasos hechos, ingredientes plegables, resumen de dónde
/// comprar y acciones.
class _RecipeResult extends StatefulWidget {
  const _RecipeResult({
    required this.entry,
    required this.currentBranchId,
    required this.onRetry,
    required this.onShowRoute,
    required this.onSelectProduct,
    required this.selectingProduct,
    required this.onExcludeIngredient,
    required this.onOpenList,
  });

  final AssistantChatEntry entry;
  final int? currentBranchId;
  final VoidCallback onRetry;
  final ValueChanged<ShoppingRoute> onShowRoute;
  final void Function(int, IngredientProductOption) onSelectProduct;
  final bool selectingProduct;
  final void Function(int, bool) onExcludeIngredient;
  final VoidCallback? onOpenList;

  @override
  State<_RecipeResult> createState() => _RecipeResultState();
}

class _RecipeResultState extends State<_RecipeResult> {
  bool _showIngredients = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final request = entry.request;
    final ingredients = request.ingredients;
    final availability = entry.availability;
    final loading = availability == null && !entry.availabilityFailed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _CardTitle(request.recipeName ?? 'Receta'),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: _StepRow(text: 'Receta reconocida', state: _StepState.done),
        ),
        Semantics(
          button: true,
          expanded: _showIngredients,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            onTap: () => setState(() => _showIngredients = !_showIngredients),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _StepRow(
                text: 'Ingredientes (${ingredients.length})',
                state: _StepState.done,
                trailing: AnimatedRotation(
                  turns: _showIngredients ? 0.5 : 0,
                  duration: AppTheme.motion(context, AppTheme.fast),
                  child: const Icon(Icons.expand_more, color: AppTheme.muted),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: AppTheme.motion(context, AppTheme.medium),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_showIngredients
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(44, 2, 0, 6),
                  child: Column(
                    children: [
                      for (final (index, ingredient) in ingredients.indexed)
                        StaggeredEntrance(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    ingredient.name,
                                    style: const TextStyle(
                                      color: AppTheme.ink,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Text(
                                  ingredientQuantity(ingredient),
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _StepRow(
            text: loading
                ? 'Consultando el inventario…'
                : 'Inventario revisado',
            state: loading ? _StepState.running : _StepState.done,
          ),
        ),
        if (loading) ...[
          const SizedBox(height: 12),
          const _ProgressBar(value: 0.7),
        ],
        const SizedBox(height: 14),
        _AvailabilitySummary(
          entry: entry,
          currentBranchId: widget.currentBranchId,
          onRetry: widget.onRetry,
          onShowRoute: widget.onShowRoute,
          onSelectProduct: widget.onSelectProduct,
          selectingProduct: widget.selectingProduct,
          onExcludeIngredient: widget.onExcludeIngredient,
        ),
        const SizedBox(height: 14),
        _OpenListButton(
          onPressed: availability == null || availability.items.isEmpty
              ? null
              : widget.onOpenList,
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
    final Widget child;
    final String key;
    if (entry.availabilityFailed) {
      key = 'failed';
      child = EmptyOrErrorState(
        compact: true,
        icon: Icons.inventory_2_outlined,
        title: 'No se pudo consultar el inventario.',
        onRetry: onRetry,
      );
    } else if (availability == null) {
      key = 'loading';
      child = const SizedBox(width: double.infinity);
    } else if (availability.items.any(
      (item) => item.productOptions.isNotEmpty || item.excluded,
    )) {
      key = 'planner';
      child = Material(
        color: Colors.transparent,
        child: _ProductPlanner(
          entry: entry,
          availability: availability,
          busy: selectingProduct,
          onSelectProduct: onSelectProduct,
          onExcludeIngredient: onExcludeIngredient,
          onShowRoute: onShowRoute,
        ),
      );
    } else {
      key = 'summary';
      final options = availability.options;
      final nowhere = availability.nowhere;
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryBanner(
            text: availability.summaryFor(currentBranchId),
            positive: availability.hasFullRoute,
          ),
          if (nowhere.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MissingProducts(items: nowhere),
          ],
          if (options.length == 1) ...[
            for (final detail in availability.detailsFor(options.single))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(detail, style: _hint),
              ),
            const SizedBox(height: 14),
            _ShowRouteButton(onPressed: () => onShowRoute(options.single)),
          ] else
            for (final (index, route) in options.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: StaggeredEntrance(
                  index: index,
                  child: _BranchOption(
                    route: route,
                    best: index == 0,
                    details: availability.detailsFor(route),
                    onTap: () => onShowRoute(route),
                  ),
                ),
              ),
        ],
      );
    }
    return SmSwitcher(
      size: true,
      child: KeyedSubtree(key: ValueKey(key), child: child),
    );
  }
}

class _ShowRouteButton extends StatelessWidget {
  const _ShowRouteButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
      icon: const Icon(Icons.route_outlined),
      label: const Text('Mostrar ruta'),
    );
  }
}

/// Supermercado sugerido, revisión de productos con casillas para quitar
/// ingredientes, y la ruta del supermercado elegido.
class _ProductPlanner extends StatefulWidget {
  const _ProductPlanner({
    required this.entry,
    required this.availability,
    required this.busy,
    required this.onSelectProduct,
    required this.onExcludeIngredient,
    required this.onShowRoute,
  });

  final AssistantChatEntry entry;
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
  bool _reviewing = false;

  Future<void> _open(PlanRow row) async {
    final availability = widget.availability;
    final result = await showProductChoiceSheet(
      context,
      item: row.item,
      options: row.options,
      selectedId: row.selected?.productId,
      quantity: quantityFor(widget.entry.request.ingredients, row.item.name),
      preferLowerPrice: availability.preferLowerPrice,
      frequentProducts: availability.frequentProducts,
    );
    if (result == null || !mounted || widget.busy) return;
    switch (result) {
      case UseProduct(:final option):
        widget.onSelectProduct(row.item.itemId, option);
      case SetIngredientExcluded(:final excluded):
        widget.onExcludeIngredient(row.item.itemId, excluded);
    }
  }

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
    final rows = planRows(
      availability,
      route ??
          (branchId == null
              ? null
              : ShoppingRoute(
                  branchId: branchId,
                  branchName: branches[branchId]!,
                  modelUrl: null,
                  stops: const [],
                )),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (branchId != null)
          _SuggestedBranch(
            name: branches[branchId]!,
            detail: route == null
                ? null
                : '${route.stops.length} ingredientes seleccionados',
            branches: branches,
            onChanged: widget.busy
                ? null
                : (value) => setState(() => _branchId = value),
          ),
        const SizedBox(height: 12),
        const Text(
          'Revisa los productos y sus etiquetas: sus atributos no están verificados.',
          style: TextStyle(color: AppTheme.muted, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _reviewing = !_reviewing),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('Revisar productos'),
              ),
            ),
            if (route != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.busy
                      ? null
                      : () => widget.onShowRoute(route),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('Mostrar ruta'),
                ),
              ),
            ],
          ],
        ),
        AnimatedSize(
          duration: AppTheme.motion(context, AppTheme.medium),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_reviewing
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, row) in rows.indexed)
                        StaggeredEntrance(
                          index: index,
                          child: _PlannerRow(
                            row: row,
                            busy: widget.busy,
                            onTap: () => _open(row),
                            onToggle: (included) => widget.onExcludeIngredient(
                              row.item.itemId,
                              !included,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        if (route != null && route.missing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Sin seleccionar: ${route.missing.join(', ')}',
              style: const TextStyle(color: AppTheme.muted, fontSize: 14),
            ),
          ),
      ],
    );
  }
}

class _PlannerRow extends StatelessWidget {
  const _PlannerRow({
    required this.row,
    required this.busy,
    required this.onTap,
    required this.onToggle,
  });

  final PlanRow row;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final excluded = row.item.excluded;
    final price = row.selected?.price;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusS),
      onTap: busy ? null : onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Row(
          children: [
            Checkbox(
              value: !excluded,
              onChanged: busy ? null : (value) => onToggle(value == true),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.item.name,
                      style: TextStyle(
                        color: excluded ? AppTheme.muted : AppTheme.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        decoration: excluded
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(
                      row.detail,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (price != null && !excluded)
              Text(
                formatBs(price),
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}

/// Supermercado sugerido; con más de uno, el menú para cambiarlo.
class _SuggestedBranch extends StatelessWidget {
  const _SuggestedBranch({
    required this.name,
    required this.detail,
    required this.branches,
    required this.onChanged,
  });

  final String name;
  final String? detail;
  final Map<int, String> branches;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppTheme.tint,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: AppTheme.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppTheme.green,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 14),
                  ),
              ],
            ),
          ),
          if (branches.length > 1)
            PopupMenuButton<int>(
              tooltip: 'Cambiar supermercado',
              enabled: onChanged != null,
              onSelected: onChanged,
              itemBuilder: (context) => [
                for (final branch in branches.entries)
                  PopupMenuItem(value: branch.key, child: Text(branch.value)),
              ],
              icon: const Icon(Icons.expand_more, color: AppTheme.green),
            ),
        ],
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.text, required this.positive});

  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppTheme.green : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: positive ? AppTheme.tint : AppTheme.warningTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            positive ? Icons.check_circle : Icons.info_outline,
            size: 22,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
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
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.substitutes.isEmpty
                        ? AppTheme.dangerTint
                        : AppTheme.warningTint,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Icon(
                    item.substitutes.isEmpty
                        ? Icons.priority_high_rounded
                        : Icons.swap_horiz_rounded,
                    size: 20,
                    color: item.substitutes.isEmpty
                        ? AppTheme.danger
                        : AppTheme.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
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
    required this.best,
    required this.details,
    required this.onTap,
  });

  final ShoppingRoute route;
  final bool best;
  final List<String> details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusL);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: best ? AppTheme.green : AppTheme.border,
          width: best ? 2 : 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.branchName,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    for (final detail in details) Text(detail, style: _hint),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Respuesta del admin: el texto y, si vienen, las barras de stock.
class _AdminAnswer extends StatelessWidget {
  const _AdminAnswer({
    required this.request,
    required this.onShowInMap,
    required this.onUpdateStock,
  });

  final AssistantRequest request;
  final ValueChanged<List<AdminAnswerRow>>? onShowInMap;
  final VoidCallback? onUpdateStock;

  @override
  Widget build(BuildContext context) {
    final rows = request.rows;
    final reference = rows.fold<double>(
      10,
      (max, row) => row.stock > max ? row.stock : max,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.tint,
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: const Row(
            children: [
              Icon(Icons.insights_outlined, color: AppTheme.green, size: 20),
              SizedBox(width: 8),
              Text(
                'Resumen de inventario',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          request.message!,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 18,
            height: 1.5,
          ),
        ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final (index, row) in rows.indexed)
            StaggeredEntrance(
              index: index,
              child: _StockBar(row: row, reference: reference),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShowInMap == null
                      ? null
                      : () => onShowInMap!(rows),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Ver en mapa'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onUpdateStock,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Actualizar stock'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Producto con su stock: rojo agotado, ámbar por agotarse, verde con stock.
class _StockBar extends StatelessWidget {
  const _StockBar({required this.row, required this.reference});

  final AdminAnswerRow row;
  final double reference;

  @override
  Widget build(BuildContext context) {
    final (Color bar, Color text) = switch (row.level) {
      StockLevel.out => (AppTheme.danger, AppTheme.danger),
      StockLevel.low => (const Color(0xFFE0A23B), AppTheme.warning),
      StockLevel.ok => (AppTheme.green, AppTheme.green),
    };
    final units = row.stock % 1 == 0
        ? row.stock.toInt().toString()
        : row.stock.toStringAsFixed(1);
    final fraction = (row.stock / reference).clamp(0.0, 1.0);
    return Semantics(
      label: '${row.name}: $units unidades',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.name,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '$units u.',
                    style: TextStyle(
                      color: text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.track,
                  borderRadius: BorderRadius.circular(5),
                ),
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fraction),
                  duration: AppTheme.motion(context, AppTheme.slow),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) =>
                      FractionallySizedBox(widthFactor: value, child: child),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 10),
                    decoration: BoxDecoration(
                      color: bar,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

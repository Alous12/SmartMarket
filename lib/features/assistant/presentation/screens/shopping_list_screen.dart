import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/horizontal_scroll_row.dart';
import '../../../../core/widgets/sm_buttons.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../auth/data/auth_api.dart';
import '../../data/assistant_api.dart';
import '../../domain/entities/recipe_availability.dart';
import '../providers/assistant_chat_provider.dart';
import '../widgets/product_choice_sheet.dart';
import '../widgets/shopping_plan.dart';
import 'branch_choice_screen.dart';

/// «Lista de compras»: cada ingrediente de la receta con su estado, ubicación y
/// precio en la sucursal elegida. Devuelve la ruta para iniciar el recorrido.
class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key, required this.requestId});

  final int requestId;

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  int? _branchId;
  bool _onlyWarnings = false;
  bool _busy = false;

  AssistantChatEntry? get _entry => ref
      .read(assistantChatProvider)
      .entries
      .where((e) => e.request.id == widget.requestId)
      .firstOrNull;

  Future<void> _run(Future<void> Function(AssistantChatEntry) action) async {
    final entry = _entry;
    if (entry == null || _busy) return;
    setState(() => _busy = true);
    try {
      await action(entry);
    } on AssistantApiException catch (error) {
      _toast(error.message);
      await ref
          .read(assistantChatProvider.notifier)
          .retryAvailability(entry.request);
    } on AuthApiException catch (error) {
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openItem(
    AssistantChatEntry entry,
    RecipeAvailability availability,
    PlanRow row,
  ) async {
    final result = await showProductChoiceSheet(
      context,
      item: row.item,
      options: row.options,
      selectedId: row.selected?.productId,
      quantity: quantityFor(entry.request.ingredients, row.item.name),
      preferLowerPrice: availability.preferLowerPrice,
      frequentProducts: availability.frequentProducts,
    );
    if (result == null || !mounted) return;
    final notifier = ref.read(assistantChatProvider.notifier);
    switch (result) {
      case UseProduct(:final option):
        await _run(
          (e) => notifier.selectProduct(e.request, row.item.itemId, option),
        );
      case SetIngredientExcluded(:final excluded):
        await _run(
          (e) => notifier.setIngredientExcluded(
            e.request,
            row.item.itemId,
            excluded,
          ),
        );
    }
  }

  Future<void> _chooseBranch(RecipeAvailability availability) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Elige el supermercado',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final route in availability.routes)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: const Icon(
                  Icons.storefront_outlined,
                  color: AppTheme.green,
                ),
                title: Text(
                  route.branchName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${route.exactCount} ingredientes exactos'),
                trailing: route.branchId == _branchId
                    ? const Icon(Icons.check_circle, color: AppTheme.green)
                    : null,
                onTap: () => Navigator.pop(context, route.branchId),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _branchId = picked);
  }

  Future<void> _openRoutes() async {
    final launch = await Navigator.of(context).push<RouteLaunch>(
      MaterialPageRoute(
        builder: (_) => BranchChoiceScreen(
          requestId: widget.requestId,
          initialBranchId: _branchId,
        ),
      ),
    );
    if (launch != null && mounted) Navigator.of(context).pop(launch);
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref
        .watch(assistantChatProvider)
        .entries
        .where((e) => e.request.id == widget.requestId)
        .firstOrNull;
    final availability = entry?.availability;
    if (entry == null || availability == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.green)),
      );
    }
    final routes = availability.routes;
    final route =
        routes.where((r) => r.branchId == _branchId).firstOrNull ??
        routes.firstOrNull;
    final branchName = route?.branchName ?? 'Sin supermercado';
    final rows = planRows(availability, route);
    final active = rows.where((r) => r.status != PlanStatus.excluded).toList();
    final available = rows
        .where((r) => r.status == PlanStatus.available)
        .length;
    final warnings = rows.where((r) => r.needsAttention).length;
    final visible = _onlyWarnings
        ? rows.where((r) => r.needsAttention).toList()
        : rows;
    final total = rows.fold<double>(
      0,
      (sum, row) => sum + (row.selected?.price ?? 0),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Row(
                children: [
                  const SmBackButton(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lista de compras',
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          entry.request.recipeName ?? 'Tu receta',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _BranchSummary(
                      branchName: branchName,
                      available: available,
                      total: active.length,
                      rows: rows,
                      onChange: routes.length > 1
                          ? () => _chooseBranch(availability)
                          : null,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 72,
                      child: HorizontalScrollRow(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                        children: [
                          PillChip(
                            label: 'Todos · ${rows.length}',
                            selected: !_onlyWarnings,
                            dark: true,
                            onTap: () => setState(() => _onlyWarnings = false),
                          ),
                          const SizedBox(width: 10),
                          PillChip(
                            label: 'Con aviso · $warnings',
                            selected: _onlyWarnings,
                            dark: true,
                            onTap: () => setState(() => _onlyWarnings = true),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    sliver: SliverList.separated(
                      itemCount: visible.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) => StaggeredEntrance(
                        index: index,
                        child: _PlanRowCard(
                          row: visible[index],
                          onTap: _busy
                              ? null
                              : () => _openItem(
                                  entry,
                                  availability,
                                  visible[index],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total estimado',
                          style: TextStyle(color: AppTheme.muted, fontSize: 15),
                        ),
                        Text(
                          formatBs(total),
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SmPrimaryButton(
                        label: 'Ver rutas de compra',
                        trailingIcon: Icons.arrow_forward_rounded,
                        onPressed: routes.isEmpty || _busy ? null : _openRoutes,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta verde con la sucursal, cuántos ingredientes hay y un segmento por
/// ingrediente: lima disponible, ámbar sustituto, oscuro lo que falta.
class _BranchSummary extends StatelessWidget {
  const _BranchSummary({
    required this.branchName,
    required this.available,
    required this.total,
    required this.rows,
    required this.onChange,
  });

  final String branchName;
  final int available;
  final int total;
  final List<PlanRow> rows;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    Color segment(PlanStatus status) => switch (status) {
      PlanStatus.available => AppTheme.lime,
      PlanStatus.substitute => const Color(0xFFF0C46A),
      _ => Colors.white.withValues(alpha: 0.22),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        decoration: BoxDecoration(
          color: AppTheme.green,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    branchName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onChange != null)
                  TextButton(
                    onPressed: onChange,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDCEFD0),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'Cambiar',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$available',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'de $total ingredientes disponibles',
                    style: const TextStyle(
                      color: Color(0xFFDCEFD0),
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                for (final (index, row) in rows.indexed) ...[
                  if (index > 0) const SizedBox(width: 6),
                  Expanded(
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: segment(row.status)),
                      duration: AppTheme.motion(context, AppTheme.slow),
                      builder: (context, color, child) => Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanRowCard extends StatelessWidget {
  const _PlanRowCard({required this.row, required this.onTap});

  final PlanRow row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color tint, Color color) = switch (row.status) {
      PlanStatus.available => (
        Icons.check_rounded,
        AppTheme.tint,
        AppTheme.green,
      ),
      PlanStatus.substitute => (
        Icons.swap_horiz_rounded,
        AppTheme.warningTint,
        AppTheme.warning,
      ),
      PlanStatus.missing => (
        Icons.priority_high_rounded,
        AppTheme.dangerTint,
        AppTheme.danger,
      ),
      PlanStatus.excluded => (
        Icons.remove_rounded,
        AppTheme.track,
        AppTheme.muted,
      ),
    };
    final price = row.selected?.price;
    final radius = BorderRadius.circular(AppTheme.radiusL);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppTheme.border, width: 1.5),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 12, 16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.item.name,
                      style: TextStyle(
                        color: row.status == PlanStatus.excluded
                            ? AppTheme.muted
                            : AppTheme.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        decoration: row.status == PlanStatus.excluded
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.detail,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                price == null ? '—' : formatBs(price),
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}

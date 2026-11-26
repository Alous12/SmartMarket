import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sm_buttons.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../store_navigation/presentation/screens/before_walking_screen.dart';
import '../../domain/entities/recipe_availability.dart';
import '../providers/assistant_chat_provider.dart';
import '../widgets/shopping_plan.dart';

/// «¿Dónde compras hoy?»: un recorrido por sucursal, la mejor primero.
/// Devuelve la ruta elegida y si se siguen los pasos.
class BranchChoiceScreen extends ConsumerStatefulWidget {
  const BranchChoiceScreen({
    super.key,
    required this.requestId,
    this.initialBranchId,
  });

  final int requestId;
  final int? initialBranchId;

  @override
  ConsumerState<BranchChoiceScreen> createState() => _BranchChoiceScreenState();
}

class _BranchChoiceScreenState extends ConsumerState<BranchChoiceScreen> {
  late int? _branchId = widget.initialBranchId;

  Future<void> _start(ShoppingRoute route) async {
    final tracking = await BeforeWalkingScreen.open(context, route.branchName);
    if (tracking == null || !mounted) return;
    Navigator.of(context).pop(RouteLaunch(route, tracking: tracking));
  }

  @override
  Widget build(BuildContext context) {
    final availability = ref
        .watch(assistantChatProvider)
        .entries
        .where((e) => e.request.id == widget.requestId)
        .firstOrNull
        ?.availability;
    final routes = availability?.routes ?? const <ShoppingRoute>[];
    final selected =
        routes.where((r) => r.branchId == _branchId).firstOrNull ??
        routes.firstOrNull;
    final wanted =
        availability?.items.where((item) => !item.excluded).length ?? 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Row(
                children: [
                  const SmBackButton(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: const Text(
                        '¿Dónde compras hoy?',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                children: [
                  const Text(
                    'Primero la que tiene más ingredientes exactos; luego la que cubre más con sustitutos.',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 17,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final (index, route) in routes.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: StaggeredEntrance(
                        index: index,
                        child: _RouteCard(
                          route: route,
                          wanted: wanted,
                          best: index == 0,
                          selected: route.branchId == selected?.branchId,
                          onTap: () =>
                              setState(() => _branchId = route.branchId),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: SmPrimaryButton(
                label: 'Iniciar recorrido',
                icon: Icons.navigation_outlined,
                onPressed: selected == null ? null : () => _start(selected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.wanted,
    required this.best,
    required this.selected,
    required this.onTap,
  });

  final ShoppingRoute route;
  final int wanted;
  final bool best;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final substitutes = route.stops.where((s) => s.isSubstitute).length;
    final missing = route.missing.map((name) => name.toLowerCase()).toList();
    final radius = BorderRadius.circular(AppTheme.radiusXL);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: AnimatedContainer(
        duration: AppTheme.motion(context, AppTheme.fast),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(
            color: selected ? AppTheme.green : AppTheme.border,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (best) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.lime,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'MEJOR OPCIÓN',
                                  style: TextStyle(
                                    color: AppTheme.ink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            Text(
                              route.branchName,
                              style: const TextStyle(
                                color: AppTheme.ink,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _Check(selected: selected),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value: '${route.exactCount}/$wanted',
                          label: 'exactos',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat(
                          value: '$substitutes',
                          label: substitutes == 1 ? 'sustituto' : 'sustitutos',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat(
                          value: '${route.stops.length}',
                          label: route.stops.length == 1 ? 'parada' : 'paradas',
                        ),
                      ),
                    ],
                  ),
                  if (missing.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      '${missing.length == 1 ? 'Falta' : 'Faltan'}: ${missing.join(', ')}',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppTheme.muted, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppTheme.motion(context, AppTheme.fast),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppTheme.green : Colors.white,
        border: Border.all(
          color: selected ? AppTheme.green : const Color(0xFFDDE1D8),
          width: 2.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 24)
          : null,
    );
  }
}

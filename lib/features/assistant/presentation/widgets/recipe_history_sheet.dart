import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_or_error_state.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../domain/entities/assistant_request.dart';
import '../providers/assistant_providers.dart';

/// Hoja con las recetas ya pedidas. Devuelve la que el usuario quiere repetir.
Future<RecipeHistoryEntry?> showRecipeHistory(BuildContext context) {
  return showModalBottomSheet<RecipeHistoryEntry>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    sheetAnimationStyle: AnimationStyle(
      curve: Curves.easeOutCubic,
      duration: AppTheme.motion(context, AppTheme.slow),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, controller) => _RecipeHistory(controller: controller),
    ),
  );
}

class _RecipeHistory extends ConsumerWidget {
  const _RecipeHistory({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(recipeHistoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text(
            'Historial de recetas',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Text(
            'Repite una ruta sin volver a consultar a la IA.',
            style: TextStyle(color: AppTheme.muted, fontSize: 14),
          ),
        ),
        Expanded(
          child: history.when(
            loading: () => ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: const [
                SkeletonBox(height: 76, radius: AppTheme.radiusM),
                SizedBox(height: 10),
                SkeletonBox(height: 76, radius: AppTheme.radiusM),
                SizedBox(height: 10),
                SkeletonBox(height: 76, radius: AppTheme.radiusM),
              ],
            ),
            error: (error, stack) => EmptyOrErrorState(
              title: 'No se pudo cargar el historial.',
              onRetry: () => ref.invalidate(recipeHistoryProvider),
            ),
            data: (entries) => entries.isEmpty
                ? const EmptyOrErrorState(
                    error: false,
                    icon: Icons.menu_book_outlined,
                    title: 'Todavía no tienes recetas guardadas.',
                    message: 'Pide un plato al asistente y aparecerá aquí.',
                  )
                : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: entries.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) => StaggeredEntrance(
                      index: index,
                      child: _HistoryTile(entry: entries[index]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final RecipeHistoryEntry entry;

  static String _date(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final count = entry.ingredientCount;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.tint,
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: const Icon(Icons.restaurant_menu, color: AppTheme.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.recipeName,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count ${count == 1 ? 'ingrediente' : 'ingredientes'} · '
                  '${_date(entry.createdAt)}',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(entry),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text('Repetir ruta'),
          ),
        ],
      ),
    );
  }
}

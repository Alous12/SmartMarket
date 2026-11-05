import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/assistant_request.dart';
import '../providers/assistant_providers.dart';

/// Hoja con las recetas ya pedidas. Devuelve la que el usuario quiere repetir.
Future<RecipeHistoryEntry?> showRecipeHistory(BuildContext context) {
  return showModalBottomSheet<RecipeHistoryEntry>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
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
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text(
            'Historial de recetas',
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'Repite una ruta sin volver a consultar a la IA.',
            style: TextStyle(color: AppTheme.muted, fontSize: 14),
          ),
        ),
        Expanded(
          child: history.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.green),
            ),
            error: (error, stack) => _HistoryMessage(
              text: 'No se pudo cargar el historial.',
              action: TextButton(
                onPressed: () => ref.invalidate(recipeHistoryProvider),
                child: const Text('Reintentar'),
              ),
            ),
            data: (entries) => entries.isEmpty
                ? const _HistoryMessage(
                    text: 'Todavía no tienes recetas guardadas.',
                  )
                : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: entries.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _HistoryTile(entry: entries[index]),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.recipeName,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
            child: const Text('Repetir ruta'),
          ),
        ],
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(color: AppTheme.muted, fontSize: 15)),
          ?action,
        ],
      ),
    );
  }
}

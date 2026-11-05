import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/auth_api.dart';
import '../../data/assistant_api.dart';
import '../../domain/entities/recipe_availability.dart';
import '../providers/assistant_chat_provider.dart';
import '../providers/assistant_providers.dart';
import '../widgets/assistant_messages.dart';
import '../widgets/recipe_history_sheet.dart';

/// Asistente SmartMarket: el usuario escribe el plato o los productos que
/// necesita comprar o preparar. Al cerrarse eligiendo una ruta devuelve la
/// [ShoppingRoute] que el mapa debe recorrer.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _requestController = TextEditingController();
  bool _repeating = false;

  @override
  void dispose() {
    _requestController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    try {
      final sent = await ref
          .read(assistantChatProvider.notifier)
          .send(_requestController.text);
      if (sent && mounted) _requestController.clear();
    } on AssistantApiException catch (error) {
      if (mounted) _showError(error.message);
    } on AuthApiException catch (error) {
      if (mounted) _showError(error.message);
    }
  }

  /// Repite una receta sin consultar a la IA. Si solo hay un supermercado posible
  /// va directo a la ruta; si no, la receta queda en el chat para elegir.
  Future<void> _openHistory() async {
    final entry = await showRecipeHistory(context);
    if (entry == null || !mounted) return;
    setState(() => _repeating = true);
    try {
      final availability = await ref
          .read(assistantChatProvider.notifier)
          .repeat(entry.id);
      if (!mounted) return;
      final options = availability.options;
      if (options.length == 1) _showRoute(options.single);
    } on AssistantApiException catch (error) {
      if (mounted) _showError(error.message);
    } on AuthApiException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _repeating = false);
    }
  }

  Future<void> _retryAvailability(AssistantChatEntry entry) async {
    try {
      await ref
          .read(assistantChatProvider.notifier)
          .retryAvailability(entry.request);
    } on AssistantApiException catch (error) {
      if (mounted) _showError(error.message);
    }
  }

  void _showRoute(ShoppingRoute route) => Navigator.of(context).pop(route);

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // Mantiene cargada la sucursal elegida para enviarla con la petición.
    final branchId = ref.watch(assistantBranchIdProvider).value;
    final chat = ref.watch(assistantChatProvider);
    final entries = chat.entries;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _AssistantHeader(repeating: _repeating, onHistory: _openHistory),
            Expanded(
              child: entries.isEmpty
                  ? _Welcome(
                      onSuggestion: (text) => _requestController.text = text,
                    )
                  : ListView.separated(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: entries.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final entry = entries[entries.length - 1 - index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            UserMessage(text: entry.request.prompt),
                            const SizedBox(height: 12),
                            AssistantReply(
                              entry: entry,
                              currentBranchId: branchId,
                              onRetryAvailability: () =>
                                  _retryAvailability(entry),
                              onShowRoute: _showRoute,
                            ),
                          ],
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _RequestField(
                controller: _requestController,
                sending: chat.sending,
                onSend: _sendRequest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Se muestra mientras el chat está vacío.
class _Welcome extends StatelessWidget {
  const _Welcome({required this.onSuggestion});

  static const _suggestions = [
    'Quiero preparar arroz con leche',
    'Quiero preparar lasaña de carne',
    'Quiero preparar un guiso de carne de res',
  ];

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AssistantAvatar(size: 56),
            const SizedBox(height: 14),
            const Text(
              '¿Qué quieres cocinar hoy?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Te digo qué supermercado tiene los ingredientes y te llevo por la ruta.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted, fontSize: 15),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final suggestion in _suggestions)
                  ActionChip(
                    label: Text(suggestion),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.border),
                    onPressed: () => onSuggestion(suggestion),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: AppTheme.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 48, height: 48, child: child),
        ),
      ),
    );
  }
}

class _AssistantHeader extends StatelessWidget {
  const _AssistantHeader({required this.repeating, required this.onHistory});

  final bool repeating;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          _RoundButton(
            tooltip: 'Volver',
            onTap: () => Navigator.maybePop(context),
            child: const Icon(Icons.chevron_left, color: AppTheme.ink),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: Color(0xFF6BB33F),
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Asistente SmartMarket',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  'Arma tu lista a partir de un plato',
                  style: TextStyle(color: AppTheme.muted, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _RoundButton(
            tooltip: 'Historial de recetas',
            onTap: repeating ? null : onHistory,
            child: repeating
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.green,
                    ),
                  )
                : const Icon(Icons.history, color: AppTheme.ink),
          ),
        ],
      ),
    );
  }
}

class _RequestField extends StatelessWidget {
  const _RequestField({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(28));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: AppTheme.ink, fontSize: 17),
            decoration: const InputDecoration(
              hintText: 'Escribe un plato o un producto…',
              hintStyle: TextStyle(color: AppTheme.muted, fontSize: 17),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 17,
              ),
              border: OutlineInputBorder(
                borderRadius: radius,
                borderSide: BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: BorderSide(color: AppTheme.lime, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: 'Enviar',
          child: Material(
            color: AppTheme.lime,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: sending ? null : onSend,
              child: SizedBox(
                width: 56,
                height: 56,
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(17),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.ink,
                        ),
                      )
                    : const Icon(Icons.near_me_outlined, color: AppTheme.ink),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

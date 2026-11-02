import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/assistant_api.dart';
import '../../domain/entities/assistant_request.dart';
import '../providers/assistant_providers.dart';

/// Asistente SmartMarket: el usuario escribe el plato o los productos que
/// necesita comprar o preparar.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  /// Consultas máximas mientras la IA procesa (unos 90 s con el intervalo por defecto).
  static const _maxPolls = 45;

  final _requestController = TextEditingController();
  final _sentRequests = <AssistantRequest>[];
  bool _sending = false;

  @override
  void dispose() {
    _requestController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    final prompt = _requestController.text;
    if (_sending || prompt.trim().isEmpty) return;

    setState(() => _sending = true);
    try {
      final session = await ref.read(authControllerProvider.future);
      if (!mounted) return;
      if (session == null) {
        _showError('Inicia sesión para enviar tu petición.');
        return;
      }
      final token = session.token;
      final branchId = await ref.read(assistantBranchIdProvider.future);
      if (!mounted) return;
      final request = await ref
          .read(assistantApiProvider)
          .sendRequest(token: token, prompt: prompt, branchId: branchId);
      if (!mounted) return;
      setState(() {
        _sentRequests.add(request);
        _requestController.clear();
      });
      // Se mantiene _sending hasta que la IA responda: una consulta a la vez.
      await _waitForAnswer(token, request);
    } on AssistantApiException catch (error) {
      if (mounted) _showError(error.message);
    } on AuthApiException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Consulta la petición hasta que la IA identifique la receta y su lista.
  Future<void> _waitForAnswer(String token, AssistantRequest request) async {
    final interval = ref.read(assistantPollIntervalProvider);
    var current = request;
    for (var poll = 0; poll < _maxPolls && !current.isFinished; poll++) {
      await Future<void>.delayed(interval);
      if (!mounted) return;
      try {
        current = await ref
            .read(assistantApiProvider)
            .fetchRequest(token: token, requestId: request.id);
      } on AssistantApiException {
        // Un fallo puntual de red no detiene la espera.
        continue;
      }
      if (!mounted) return;
      _updateRequest(current);
    }
    if (!current.isFinished && mounted) {
      _updateRequest(
        AssistantRequest(
          id: current.id,
          prompt: current.prompt,
          status: AssistantRequestStatus.failed,
          message:
              'El asistente está tardando más de lo normal. Inténtalo de nuevo en unos minutos.',
        ),
      );
    }
  }

  void _updateRequest(AssistantRequest request) {
    final index = _sentRequests.indexWhere((sent) => sent.id == request.id);
    if (index == -1) return;
    setState(() => _sentRequests[index] = request);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // Mantiene cargada la sucursal elegida para enviarla con la petición.
    ref.watch(assistantBranchIdProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _AssistantHeader(),
            Expanded(
              child: ListView.separated(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                itemCount: _sentRequests.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final request =
                      _sentRequests[_sentRequests.length - 1 - index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _UserMessage(text: request.prompt),
                      const SizedBox(height: 12),
                      _AssistantReply(request: request),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: _RequestField(
                controller: _requestController,
                sending: _sending,
                onSend: _sendRequest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Burbuja con la petición enviada por el usuario.
class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.text});

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
          decoration: BoxDecoration(
            color: AppTheme.lime,
            borderRadius: BorderRadius.circular(18),
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

/// Respuesta del asistente: progreso, receta con su lista de ingredientes o
/// el motivo por el que no se pudo atender la petición.
class _AssistantReply extends StatelessWidget {
  const _AssistantReply({required this.request});

  final AssistantRequest request;

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
    final recipeName = request.recipeName;
    final Widget content = switch (request.status) {
      AssistantRequestStatus.received ||
      AssistantRequestStatus.processing => Row(
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
              recipeName == null
                  ? 'Identificando la receta…'
                  : 'Preparando la lista de $recipeName…',
              style: const TextStyle(color: AppTheme.muted, fontSize: 16),
            ),
          ),
        ],
      ),
      AssistantRequestStatus.completed => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.restaurant_menu,
                size: 20,
                color: AppTheme.green,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  recipeName ?? 'Receta',
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ingredientes (${request.ingredients.length})',
            style: const TextStyle(color: AppTheme.muted, fontSize: 14),
          ),
          const SizedBox(height: 8),
          for (final ingredient in request.ingredients)
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

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: content,
        ),
      ),
    );
  }
}

class _AssistantHeader extends StatelessWidget {
  const _AssistantHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Tooltip(
            message: 'Volver',
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(
                side: BorderSide(color: AppTheme.border),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.canPop()
                    ? context.pop()
                    : Navigator.maybePop(context),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.chevron_left, color: AppTheme.ink),
                ),
              ),
            ),
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

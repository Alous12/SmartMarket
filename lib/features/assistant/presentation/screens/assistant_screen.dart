import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
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
      final request = await ref
          .read(assistantApiProvider)
          .sendRequest(token: token, prompt: prompt);
      if (!mounted) return;
      setState(() {
        _sentRequests.add(request);
        _requestController.clear();
      });
    } on AssistantApiException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                itemBuilder: (context, index) => _UserMessage(
                  text: _sentRequests[_sentRequests.length - 1 - index].prompt,
                ),
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
              shape: const CircleBorder(side: BorderSide(color: AppTheme.border)),
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
                    Icon(Icons.auto_awesome, size: 20, color: Color(0xFF6BB33F)),
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
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 17),
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

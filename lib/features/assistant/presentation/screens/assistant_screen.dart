import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

/// Asistente SmartMarket: el usuario escribe el plato o los productos que
/// necesita comprar o preparar.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _requestController = TextEditingController();

  @override
  void dispose() {
    _requestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _AssistantHeader(),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: _RequestField(controller: _requestController),
            ),
          ],
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
  const _RequestField({required this.controller});

  final TextEditingController controller;

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
        // Botón de envío del diseño; el envío de la solicitud es otra historia.
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppTheme.lime,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.near_me_outlined, color: AppTheme.ink),
        ),
      ],
    );
  }
}

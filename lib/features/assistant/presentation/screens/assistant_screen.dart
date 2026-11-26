import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/horizontal_scroll_row.dart';
import '../../../../core/widgets/sm_buttons.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../store_navigation/domain/entities/store_model.dart';
import '../../../store_navigation/presentation/providers/store_model_provider.dart';
import '../../../store_navigation/presentation/widgets/store_labels.dart';
import '../../data/assistant_api.dart';
import '../../domain/entities/assistant_request.dart';
import '../../domain/entities/recipe_availability.dart';
import '../providers/assistant_chat_provider.dart';
import '../providers/assistant_providers.dart';
import '../widgets/assistant_messages.dart';
import '../widgets/recipe_history_sheet.dart';
import '../widgets/shopping_plan.dart';
import 'shopping_list_screen.dart';

/// Asistente SmartMarket: el usuario escribe el plato o los productos que
/// necesita comprar o preparar. Al elegir una ruta, el mapa la recorre: como
/// pestaña se la envía y lo abre; abierto encima de otra pantalla, la devuelve.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _requestController = TextEditingController();
  bool _repeating = false;
  bool _selectingProduct = false;
  String? _selectedModel;

  @override
  void dispose() {
    _requestController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    try {
      final sent = await ref
          .read(assistantChatProvider.notifier)
          .send(_requestController.text, modelId: _selectedModel);
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
      if (options.length == 1 &&
          availability.items.every((item) => item.productOptions.isEmpty)) {
        _showRoute(options.single);
      }
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

  Future<void> _retryPolling(AssistantChatEntry entry) async {
    try {
      await ref
          .read(assistantChatProvider.notifier)
          .retryPolling(entry.request);
    } on AssistantApiException catch (error) {
      if (mounted) _showError(error.message);
    } on AuthApiException catch (error) {
      if (mounted) _showError(error.message);
    }
  }

  Future<void> _selectProduct(
    AssistantChatEntry entry,
    int itemId,
    IngredientProductOption option,
  ) async {
    if (_selectingProduct) return;
    setState(() => _selectingProduct = true);
    try {
      await ref
          .read(assistantChatProvider.notifier)
          .selectProduct(entry.request, itemId, option);
    } on AssistantApiException catch (error) {
      if (mounted) _showError(error.message);
      await _retryAvailability(entry);
    } on AuthApiException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _selectingProduct = false);
    }
  }

  Future<void> _setExcluded(
    AssistantChatEntry entry,
    int itemId,
    bool excluded,
  ) async {
    if (_selectingProduct) return;
    setState(() => _selectingProduct = true);
    try {
      await ref
          .read(assistantChatProvider.notifier)
          .setIngredientExcluded(entry.request, itemId, excluded);
    } on AssistantApiException catch (error) {
      if (mounted) _showError(error.message);
      await _retryAvailability(entry);
    } on AuthApiException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _selectingProduct = false);
    }
  }

  void _showRoute(ShoppingRoute route, {bool tracking = true}) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(route);
      return;
    }
    ref
        .read(mapRequestProvider.notifier)
        .send(ShowRouteRequest(route, tracking: tracking));
    context.goNamed('supermarket');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// «Ver lista de compras»: la lista completa y, desde ella, las sucursales.
  Future<void> _openList(AssistantChatEntry entry) async {
    final launch = await Navigator.of(context, rootNavigator: true)
        .push<RouteLaunch>(
          MaterialPageRoute(
            builder: (_) => ShoppingListScreen(requestId: entry.request.id),
          ),
        );
    if (launch != null && mounted) {
      _showRoute(launch.route, tracking: launch.tracking);
    }
  }

  /// Respuesta del admin: señala en el mapa el primer producto de la lista.
  Future<void> _showRowsInMap(List<AdminAnswerRow> rows) async {
    final first = rows.firstOrNull;
    if (first != null) {
      try {
        final model = await ref.read(storeModelProvider.future);
        final product = model.metadata.products
            .where((p) => p.dbId == first.productId)
            .firstOrNull;
        if (product != null) {
          ref
              .read(mapRequestProvider.notifier)
              .send(FocusProductRequest(product.id));
        }
      } on Object {
        // Sin modelo solo se abre el mapa.
      }
    }
    if (mounted) context.goNamed('supermarket');
  }

  void _updateStock() {
    ref.read(mapRequestProvider.notifier).send(const StartEditRequest());
    context.goNamed('supermarket');
  }

  Future<void> _chooseStore() async {
    final store = await showModalBottomSheet<Supermarket>(
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
            for (final option in Supermarket.values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: const Icon(
                  Icons.storefront_outlined,
                  color: AppTheme.green,
                ),
                title: Text(
                  option.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: option == ref.read(selectedStoreProvider)
                    ? const Icon(Icons.check_circle, color: AppTheme.green)
                    : null,
                onTap: () => Navigator.pop(context, option),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (store != null) {
      ref.read(mapRequestProvider.notifier).send(SelectStoreRequest(store));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mantiene cargada la sucursal elegida para enviarla con la petición.
    final branchId = ref.watch(assistantBranchIdProvider).value;
    final chat = ref.watch(assistantChatProvider);
    final entries = chat.entries;
    final isAdmin =
        ref.watch(authControllerProvider).asData?.value?.isAdmin ?? false;
    final store = ref.watch(selectedStoreProvider);
    final locked = ref.watch(lockedStoreProvider) != null;
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      body: Column(
        children: [
          if (isAdmin)
            _AdminHeader(storeName: store.displayName, canPop: canPop)
          else
            SafeArea(
              bottom: false,
              child: _ClientHeader(
                canPop: canPop,
                repeating: _repeating,
                onHistory: _openHistory,
                chips: [
                  PillChip(
                    label: store.displayName,
                    selected: false,
                    tinted: true,
                    icon: Icons.location_on_outlined,
                    trailingIcon: locked ? null : Icons.expand_more_rounded,
                    onTap: locked || chat.sending ? null : _chooseStore,
                  ),
                  const SizedBox(width: 10),
                  ref
                      .watch(assistantModelsProvider)
                      .when(
                        data: (models) => _ModelChip(
                          models: models,
                          selected: _selectedModel,
                          enabled: !chat.sending,
                          onSelected: (value) =>
                              setState(() => _selectedModel = value),
                        ),
                        error: (error, stack) => PillChip(
                          label:
                              'No se pudieron cargar los modelos. Reintentar',
                          selected: false,
                          icon: Icons.refresh,
                          onTap: () => ref.invalidate(assistantModelsProvider),
                        ),
                        loading: () => const PillChip(
                          label: 'Cargando modelos…',
                          selected: false,
                          onTap: null,
                        ),
                      ),
                ],
              ),
            ),
          Expanded(
            child: SmSwitcher(
              child: entries.isEmpty
                  ? _Welcome(key: const ValueKey('welcome'), admin: isAdmin)
                  : ListView.separated(
                      key: const ValueKey('chat'),
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      itemCount: entries.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 22),
                      itemBuilder: (context, index) {
                        final entry = entries[entries.length - 1 - index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            UserMessage(
                              text: entry.request.prompt,
                              admin: isAdmin,
                            ),
                            const SizedBox(height: 18),
                            AssistantReply(
                              entry: entry,
                              currentBranchId: branchId,
                              onRetryAvailability: () =>
                                  _retryAvailability(entry),
                              onRetryPolling: () => _retryPolling(entry),
                              onShowRoute: _showRoute,
                              selectingProduct: _selectingProduct,
                              onSelectProduct: (itemId, option) =>
                                  _selectProduct(entry, itemId, option),
                              onExcludeIngredient: (itemId, excluded) =>
                                  _setExcluded(entry, itemId, excluded),
                              onOpenList: () => _openList(entry),
                              onShowRowsInMap: _showRowsInMap,
                              onUpdateStock: _updateStock,
                              admin: isAdmin,
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
          _Suggestions(
            admin: isAdmin,
            onSuggestion: (text) => _requestController.text = text,
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: _RequestField(
                controller: _requestController,
                sending: chat.sending,
                onSend: _sendRequest,
                admin: isAdmin,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cabecera del cliente: subtítulo, título grande, historial y chips.
class _ClientHeader extends StatelessWidget {
  const _ClientHeader({
    required this.canPop,
    required this.repeating,
    required this.onHistory,
    required this.chips,
  });

  final bool canPop;
  final bool repeating;
  final VoidCallback onHistory;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Row(
            children: [
              if (canPop) ...[const SmBackButton(), const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Asistente SmartMarket',
                      style: TextStyle(color: AppTheme.muted, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Semantics(
                      header: true,
                      child: const Text(
                        '¿Qué quieres cocinar hoy?',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              repeating
                  ? const SizedBox(
                      width: 56,
                      height: 56,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.green,
                        ),
                      ),
                    )
                  : SmSquareButton(
                      icon: Icons.history_rounded,
                      tooltip: 'Historial de recetas',
                      onPressed: onHistory,
                    ),
            ],
          ),
        ),
        SizedBox(
          height: 52,
          child: HorizontalScrollRow(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            children: chips,
          ),
        ),
      ],
    );
  }
}

/// Cabecera oscura del asistente de inventario del admin.
class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.storeName, required this.canPop});

  final String storeName;
  final bool canPop;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.night,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Row(
            children: [
              if (canPop) ...[
                const SmBackButton(dark: true),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ASISTENTE DE INVENTARIO',
                      style: TextStyle(
                        color: AppTheme.lime,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      storeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Se muestra mientras el chat está vacío.
class _Welcome extends StatelessWidget {
  const _Welcome({super.key, required this.admin});

  final bool admin;

  @override
  Widget build(BuildContext context) {
    final steps = admin
        ? const [
            (Icons.chat_bubble_outline, 'Pregunta en tus palabras'),
            (Icons.inventory_2_outlined, 'Consulto el inventario real'),
            (Icons.insights_outlined, 'Te respondo con los datos'),
          ]
        : const [
            (Icons.restaurant_menu, 'Escribe el plato'),
            (Icons.checklist_rounded, 'Armo la lista de ingredientes'),
            (Icons.route_outlined, 'Te llevo por la ruta'),
          ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AssistantAvatar(size: 64)),
              const SizedBox(height: 16),
              if (admin) ...[
                const Text(
                  '¿Qué quieres saber de tu supermercado?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                admin
                    ? 'Consulta el inventario, categorías, stock y ubicaciones de tu sucursal.'
                    : 'Te digo qué supermercado tiene los ingredientes y te llevo por la ruta.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              for (final (index, (icon, text)) in steps.indexed)
                StaggeredEntrance(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.tint,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusS,
                            ),
                          ),
                          child: Icon(icon, size: 22, color: AppTheme.green),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            text,
                            style: const TextStyle(
                              color: AppTheme.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
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
    );
  }
}

/// Sugerencias en una fila con desplazamiento horizontal sobre el campo.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.admin, required this.onSuggestion});

  static const _suggestions = [
    'Quiero preparar arroz con leche',
    'Quiero preparar lasaña de carne',
    'Quiero preparar un guiso de carne de res',
  ];
  static const _adminSuggestions = [
    '¿Qué productos están por agotarse?',
    'Haz un resumen del inventario',
    '¿Cuáles son los productos con más stock?',
  ];

  final bool admin;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final items = admin ? _adminSuggestions : _suggestions;
    return SizedBox(
      height: 52,
      child: HorizontalScrollRow(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          for (final (index, suggestion) in items.indexed) ...[
            if (index > 0) const SizedBox(width: 10),
            PillChip(
              label: suggestion,
              selected: false,
              onTap: () => onSuggestion(suggestion),
            ),
          ],
        ],
      ),
    );
  }
}

/// Selector del modelo de IA como chip blanco con flecha.
class _ModelChip extends StatelessWidget {
  const _ModelChip({
    required this.models,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  /// Valor del menú para «Predeterminado» (el selector usa null).
  static const _defaultValue = '';

  final List<AssistantModel> models;
  final String? selected;
  final bool enabled;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final current = models.where((model) => model.id == selected).firstOrNull;
    return PopupMenuButton<String>(
      tooltip: 'Modelo de IA',
      enabled: enabled,
      initialValue: selected ?? _defaultValue,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      onSelected: (value) => onSelected(value == _defaultValue ? null : value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _defaultValue,
          child: Text('Predeterminado'),
        ),
        for (final model in models)
          PopupMenuItem(value: model.id, child: Text(model.label)),
      ],
      child: IgnorePointer(
        child: PillChip(
          label: current?.label ?? 'Predeterminado',
          selected: false,
          trailingIcon: Icons.expand_more_rounded,
          onTap: () {},
        ),
      ),
    );
  }
}

class _RequestField extends StatelessWidget {
  const _RequestField({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.admin,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusL);
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: Color(0xFFDDE1D8), width: 1.5),
    );
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
            decoration: InputDecoration(
              hintText: admin
                  ? 'Pregunta lo que quieras sobre tu sucursal…'
                  : 'Escribe un plato o un producto…',
              hintStyle: const TextStyle(color: AppTheme.muted, fontSize: 17),
              filled: true,
              fillColor: Colors.white,
              constraints: const BoxConstraints(minHeight: 60),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: const BorderSide(color: AppTheme.green, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: 'Enviar',
          child: Semantics(
            button: true,
            enabled: !sending,
            label: 'Enviar',
            child: AnimatedContainer(
              duration: AppTheme.motion(context, AppTheme.fast),
              decoration: BoxDecoration(
                color: sending
                    ? AppTheme.track
                    : admin
                    ? AppTheme.night
                    : AppTheme.green,
                borderRadius: radius,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: radius,
                  onTap: sending ? null : onSend,
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: sending
                        ? const Padding(
                            padding: EdgeInsets.all(18),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.green,
                            ),
                          )
                        : const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers/store_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_or_error_state.dart';
import '../../../../core/widgets/sm_buttons.dart';
import '../../../../core/widgets/sm_search_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/store_model.dart';
import '../../domain/services/store_layout.dart';
import '../controllers/product_creation.dart';
import '../providers/store_model_provider.dart';
import '../widgets/bottom_action.dart';
import '../widgets/layout_sheets.dart';
import '../widgets/layout_widgets.dart';
import '../widgets/store_edit_sheets.dart' show showProductForm;
import '../widgets/store_labels.dart';

/// Lo que el admin está colocando: un producto de un espacio ([fromSlot]) que
/// se intercambia o mueve, o uno del inventario ([fromSlot] null).
class _Placement {
  const _Placement(this.product, {this.fromSlot});

  final StoreProduct product;
  final String? fromSlot;
}

enum _MenuAction { map3d, staff, refresh, logout }

/// Plano 2D del admin: los pasillos con nombre, los estantes de cada uno y lo
/// que hay en cada espacio. Tocar un espacio permite intercambiarlo con otro,
/// reemplazarlo por un producto del inventario, editarlo o retirarlo.
class StoreLayoutScreen extends ConsumerStatefulWidget {
  const StoreLayoutScreen({super.key});

  @override
  ConsumerState<StoreLayoutScreen> createState() => _StoreLayoutScreenState();
}

class _StoreLayoutScreenState extends ConsumerState<StoreLayoutScreen> {
  String? _aisleKey;
  String _query = '';
  final _search = TextEditingController();
  _Placement? _placing;
  String? _focusSlot;
  Timer? _focusTimer;
  bool _busy = false;

  /// El mapa 3D está abierto encima: él atiende las peticiones mientras tanto.
  bool _mapOpen = false;
  final _shelfKeys = <String, GlobalKey>{};

  StoreModel? _layoutModel;
  StoreLayout? _layout;

  @override
  void initState() {
    super.initState();
    ref.listenManual(mapRequestProvider, (previous, request) {
      // Se atiende fuera del build: la petición puede llegar antes del primero.
      if (request != null) Future.microtask(() => _handleRequest(request));
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  StoreLayout _layoutOf(StoreModel model) {
    if (!identical(model, _layoutModel) || _layout == null) {
      _layoutModel = model;
      _layout = buildStoreLayout(
        products: model.metadata.products,
        emptySlots: model.emptySlots,
      );
    }
    return _layout!;
  }

  String _nameOf(StoreProduct product) =>
      (ref.read(productNamesProvider).value ?? const {})[product.id] ??
      product.name;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<StoreModel?> _currentModel() async {
    try {
      return await ref.read(storeModelProvider.future);
    } on Object {
      return null;
    }
  }

  Future<void> _handleRequest(MapRequest request) async {
    if (!mounted || _mapOpen) return;
    final notifier = ref.read(mapRequestProvider.notifier);
    switch (request) {
      case ShowRouteRequest(:final route):
        final locked = ref.read(lockedStoreProvider);
        if (locked != null && route.modelUrl != locked.assetPath) {
          notifier.clear();
          _toast('Tu cuenta solo puede ver ${locked.title}.');
          return;
        }
        // La ruta se sigue en el mapa 3D: él toma la petición al abrirse.
        await _openMap();
      case FocusProductRequest(:final productId):
        notifier.clear();
        final model = await _currentModel();
        if (model == null || !mounted) return;
        final found = _layoutOf(model).locateProduct(productId);
        if (found != null) _focus(found.$3.code);
      case PlaceProductRequest(:final dbId):
        notifier.clear();
        final model = await _currentModel();
        if (model == null || !mounted) return;
        final layout = _layoutOf(model);
        final placed = layout.locateDbProduct(dbId);
        if (placed != null) {
          _focus(placed.$3.code);
          _startPlacement(placed.$3.product!, fromSlot: placed.$3.code);
          return;
        }
        final product = model.unplaced
            .where((p) => p.dbId == dbId)
            .firstOrNull;
        if (product != null) _startPlacement(product);
      case StartEditRequest():
      case SelectStoreRequest():
        // El plano ya es el modo de edición y la sucursal del admin es fija.
        notifier.clear();
    }
  }

  Future<void> _openMap() async {
    if (_mapOpen) return;
    _mapOpen = true;
    try {
      await context.pushNamed('map3d');
    } finally {
      _mapOpen = false;
    }
  }

  /// Señala el espacio [code]: elige su pasillo y lleva la vista a su estante.
  void _focus(String code) {
    final found = _layout?.locate(code);
    if (found == null) return;
    final (aisle, shelf, _) = found;
    _focusTimer?.cancel();
    setState(() {
      _aisleKey = aisle.key;
      _focusSlot = code;
      _query = '';
      _search.clear();
    });
    _focusTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _focusSlot = null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _shelfKeys['${aisle.key}/${shelf.code}']?.currentContext;
      if (context == null || !context.mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.2,
        duration: AppTheme.motion(context, AppTheme.slow),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _startPlacement(StoreProduct product, {String? fromSlot}) {
    HapticFeedback.selectionClick();
    setState(() {
      _placing = _Placement(product, fromSlot: fromSlot);
      _query = '';
      _search.clear();
    });
  }

  void _cancelPlacement() => setState(() => _placing = null);

  /// Ejecuta un cambio en la base de datos, recarga el plano y avisa.
  Future<bool> _run(
    Future<void> Function() action, {
    required String success,
    required String failure,
    String? focus,
    VoidCallback? onSuccess,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      _toast(catalogErrorMessage(error, failure));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) onSuccess?.call();
    ref.invalidate(storeModelProvider);
    _toast(success);
    if (focus != null) {
      // Se espera al plano nuevo para señalar el espacio.
      await _currentModel();
      if (mounted) _focus(focus);
    }
    return true;
  }

  bool _canEdit(StoreModel model) {
    if (model.fromCatalog) return true;
    _toast(
      'No hay conexión con el servidor: los estantes no se pueden editar ahora.',
    );
    return false;
  }

  Future<void> _onSlotTap(StoreModel model, LayoutSlot slot) async {
    if (_busy || !_canEdit(model)) return;
    if (_placing != null) {
      await _completePlacement(model, slot);
      return;
    }
    final layout = _layoutOf(model);
    final product = slot.product;
    final place = layout.placeOf(slot.code);
    final action = await showSlotSheet(
      context,
      slot: slot,
      name: product == null ? '' : _nameOf(product),
      place: place,
      unplacedCount: model.unplaced.length,
    );
    if (action == null || !mounted) return;
    final api = ref.read(catalogApiProvider);
    switch (action) {
      case SlotSheetAction.swap:
        _startPlacement(product!, fromSlot: slot.code);
      case SlotSheetAction.replaceFromInventory:
        final pick = await _pickFromInventory(
          model,
          title: 'Reemplazar "${_nameOf(product!)}"',
          subtitle: place,
          excludeDbId: product.dbId,
        );
        if (pick == null || !mounted) return;
        final from = _placeOfProduct(layout, pick);
        final message = from == null
            ? '"${_nameOf(pick)}" irá a $place y "${_nameOf(product)}" '
                  'pasará al inventario.'
            : '"${_nameOf(pick)}" ($from) y "${_nameOf(product)}" '
                  'cambiarán de lugar.';
        if (!await confirmLayoutChange(
          context,
          title: from == null ? 'Reemplazar producto' : 'Intercambiar productos',
          message: message,
          confirm: from == null ? 'Reemplazar' : 'Intercambiar',
        )) {
          return;
        }
        await _run(
          () => api.assignToSlot(slot.code, pick.dbId!),
          success: from == null
              ? '"${_nameOf(pick)}" ocupa el espacio. '
                    '"${_nameOf(product)}" quedó en el inventario.'
              : 'Se intercambiaron "${_nameOf(pick)}" y "${_nameOf(product)}".',
          failure: 'No se pudo reemplazar el producto.',
          focus: slot.code,
        );
      case SlotSheetAction.sendToInventory:
        if (!await confirmLayoutChange(
          context,
          title: 'Enviar al inventario',
          message:
              '"${_nameOf(product!)}" saldrá de $place y quedará en el '
              'inventario con su stock. El asistente no lo ofrecerá hasta '
              'que vuelva a un estante.',
          confirm: 'Enviar',
        )) {
          return;
        }
        await _run(
          () => api.clearSlot(slot.code),
          success: '"${_nameOf(product)}" está en el inventario.',
          failure: 'No se pudo enviar el producto al inventario.',
        );
      case SlotSheetAction.edit:
        final form = await showProductForm(
          context,
          title: 'Editar producto',
          name: product!.name,
          price: product.price,
          stock: product.stock,
        );
        if (form == null || !mounted) return;
        await _run(
          () => api.updateProduct(
            product.dbId!,
            name: form.name,
            price: form.price,
            stock: form.stock,
          ),
          success: 'Cambios guardados.',
          failure: 'No se pudo guardar el producto.',
          focus: slot.code,
        );
      case SlotSheetAction.remove:
        if (!await confirmLayoutChange(
          context,
          title: 'Quitar producto',
          message:
              '¿Quitar "${_nameOf(product!)}" de la sucursal? Se eliminará '
              'su stock y ubicación en la base de datos.',
          confirm: 'Quitar',
          danger: true,
        )) {
          return;
        }
        await _run(
          () => api.removeProduct(product.dbId!),
          success: '"${_nameOf(product)}" se quitó de la sucursal.',
          failure: 'No se pudo quitar el producto.',
        );
      case SlotSheetAction.placeFromInventory:
        final pick = await _pickFromInventory(
          model,
          title: 'Poner en este espacio',
          subtitle: place,
        );
        if (pick == null || !mounted) return;
        await _placeInto(model, pick, slot);
      case SlotSheetAction.createHere:
        await createProductFlow(
          context,
          ref,
          layout: layout,
          presetSlot: slot.code,
        );
    }
  }

  String? _placeOfProduct(StoreLayout layout, StoreProduct product) =>
      product.slotId.isEmpty ? null : layout.placeOf(product.slotId);

  Future<StoreProduct?> _pickFromInventory(
    StoreModel model, {
    required String title,
    required String subtitle,
    int? excludeDbId,
  }) {
    final layout = _layoutOf(model);
    return showInventoryPicker(
      context,
      title: title,
      subtitle: subtitle,
      unplaced: model.unplaced,
      placed: model.metadata.products,
      placeOf: (product) => _placeOfProduct(layout, product),
      nameOf: _nameOf,
      excludeDbId: excludeDbId,
    );
  }

  /// Pone [product] (del inventario o de otro espacio) en [target]. Devuelve
  /// false si el admin no lo confirmó o si falló.
  Future<bool> _placeInto(
    StoreModel model,
    StoreProduct product,
    LayoutSlot target, {
    VoidCallback? onSuccess,
  }) async {
    final layout = _layoutOf(model);
    final api = ref.read(catalogApiProvider);
    final to = layout.placeOf(target.code);
    final from = _placeOfProduct(layout, product);
    final name = _nameOf(product);
    final displaced = target.product;
    if (from != null || displaced != null) {
      final message = switch ((from, displaced)) {
        (final f?, null) => '"$name" se moverá de $f a $to.',
        (final f?, final d?) =>
          '"$name" ($f) y "${_nameOf(d)}" ($to) cambiarán de lugar.',
        (null, final d?) =>
          '"$name" irá a $to y "${_nameOf(d)}" pasará al inventario.',
        (null, null) => '',
      };
      if (!await confirmLayoutChange(
        context,
        title: displaced == null ? 'Mover producto' : 'Confirmar cambio',
        message: message,
        confirm: displaced == null ? 'Mover' : 'Confirmar',
      )) {
        return false;
      }
    }
    return _run(
      () => from != null
          ? api.moveSlot(product.slotId, target.code)
          : api.assignToSlot(target.code, product.dbId!),
      success: switch ((from, displaced)) {
        (_?, null) => '"$name" se movió a $to.',
        (_?, final d?) => 'Se intercambiaron "$name" y "${_nameOf(d)}".',
        (null, final d?) =>
          '"$name" está en $to. "${_nameOf(d)}" quedó en el inventario.',
        (null, null) => '"$name" está en $to.',
      },
      failure: 'No se pudo colocar el producto.',
      focus: target.code,
      onSuccess: onSuccess,
    );
  }

  Future<void> _completePlacement(StoreModel model, LayoutSlot target) async {
    final placing = _placing!;
    if (placing.fromSlot == target.code) {
      _cancelPlacement();
      return;
    }
    final layout = _layoutOf(model);
    final product = placing.fromSlot == null
        ? placing.product
        : layout.locate(placing.fromSlot!)?.$3.product;
    if (product == null) {
      _cancelPlacement();
      return;
    }
    // Si el admin cancela la confirmación o falla, puede elegir otro destino.
    await _placeInto(
      model,
      product,
      target,
      onSuccess: () => setState(() => _placing = null),
    );
  }

  Future<void> _browseInventory(StoreModel model) async {
    if (!_canEdit(model)) return;
    final pick = await _pickFromInventory(
      model,
      title: 'Inventario',
      subtitle: 'Elige un producto para ponerlo en un estante',
    );
    if (pick == null || !mounted) return;
    if (pick.slotId.isNotEmpty) {
      _focus(pick.slotId);
      _startPlacement(pick, fromSlot: pick.slotId);
    } else {
      _startPlacement(pick);
    }
  }

  Future<void> _logout() async {
    try {
      await ref.read(authControllerProvider.notifier).logout();
      if (mounted) context.goNamed('login');
    } on Object catch (error) {
      _toast('No se pudo cerrar la sesión: $error');
    }
  }

  Future<void> _onMenu(_MenuAction action) async {
    switch (action) {
      case _MenuAction.map3d:
        await _openMap();
      case _MenuAction.staff:
        await context.pushNamed('staff');
      case _MenuAction.refresh:
        ref.invalidate(storeModelProvider);
      case _MenuAction.logout:
        await _logout();
    }
  }

  Future<void> _onBack() async {
    if (_placing != null) {
      _cancelPlacement();
      return;
    }
    if (_query.isNotEmpty) {
      setState(() {
        _query = '';
        _search.clear();
      });
      return;
    }
    if (await confirmExit(context) && mounted) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(storeModelProvider);
    ref.watch(productNamesProvider);
    final store = ref.watch(selectedStoreProvider);
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: model.when(
          loading: () => Column(
            children: [
              _Header(store: store, layout: null, onMenu: _onMenu),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.green),
                ),
              ),
            ],
          ),
          error: (error, stack) => Column(
            children: [
              _Header(store: store, layout: null, onMenu: _onMenu),
              Expanded(
                child: EmptyOrErrorState(
                  icon: Icons.grid_view_rounded,
                  title: 'No se pudo cargar el plano.',
                  message:
                      'Revisa tu conexión o que el servidor esté encendido e inténtalo otra vez.',
                  onRetry: () => ref.invalidate(storeModelProvider),
                ),
              ),
            ],
          ),
          data: (model) => _buildLayout(context, model),
        ),
      ),
    );
  }

  Widget _buildLayout(BuildContext context, StoreModel model) {
    final layout = _layoutOf(model);
    final aisles = layout.aisles;
    final aisle =
        aisles.where((a) => a.key == _aisleKey).firstOrNull ??
        aisles.firstOrNull;
    final placing = _placing;
    final query = normalizeForSearch(_query.trim());

    SlotTone toneOf(LayoutSlot slot) {
      if (placing != null) {
        return slot.code == placing.fromSlot ? SlotTone.source : SlotTone.target;
      }
      return slot.code == _focusSlot ? SlotTone.focused : SlotTone.normal;
    }

    String slotName(LayoutSlot slot) =>
        slot.product == null ? '' : _nameOf(slot.product!);

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: _Header(store: model.store, layout: layout, onMenu: _onMenu),
      ),
      if (!model.fromCatalog)
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningTint,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: const Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: AppTheme.warning),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sin conexión con el servidor: se muestran los datos del '
                    'modelo y no se pueden guardar cambios.',
                    style: TextStyle(color: AppTheme.warning, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      if (placing != null)
        SliverToBoxAdapter(
          child: PlacementBanner(
            title: placing.fromSlot == null
                ? 'Colocando "${_nameOf(placing.product)}"'
                : 'Intercambiando "${_nameOf(placing.product)}"',
            subtitle: placing.fromSlot == null
                ? 'Elige el pasillo y toca un espacio libre u ocupado.'
                : 'Elige el pasillo, el estante y el producto de destino.',
            onCancel: _cancelPlacement,
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border: Border.all(color: AppTheme.border, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StorePlan(
                  layout: layout,
                  selectedAisle: aisle?.key,
                  focusedSlot: _focusSlot,
                  sourceSlot: placing?.fromSlot,
                  onAisleSelected: (key) => setState(() => _aisleKey = key),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(6, 8, 6, 2),
                  child: Text(
                    'Vista desde arriba · toca un sector para ver su pasillo',
                    style: TextStyle(color: AppTheme.muted, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
          child: SmSearchField(
            hintText: 'Buscar producto en el plano o el inventario',
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
      ),
    ];

    if (query.isNotEmpty) {
      slivers.addAll(_searchResults(model, layout, query));
    } else {
      slivers.add(
        SliverToBoxAdapter(
          child: AisleChips(
            aisles: aisles,
            selected: aisle?.key,
            onSelected: (key) => setState(() => _aisleKey = key),
          ),
        ),
      );
      if (aisle == null) {
        slivers.add(
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Este supermercado no tiene estantes en su modelo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted, fontSize: 16),
              ),
            ),
          ),
        );
      } else {
        slivers
          ..add(SliverToBoxAdapter(child: _AisleHeader(aisle: aisle)))
          ..add(
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              sliver: SliverList.separated(
                itemCount: aisle.shelves.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final shelf = aisle.shelves[index];
                  return ShelfCard(
                    key: _shelfKeys.putIfAbsent(
                      '${aisle.key}/${shelf.code}',
                      GlobalKey.new,
                    ),
                    shelf: shelf,
                    toneOf: toneOf,
                    nameOf: slotName,
                    onSlotTap: (slot) => _onSlotTap(model, slot),
                  );
                },
              ),
            ),
          );
      }
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              RefreshIndicator(
                color: AppTheme.green,
                onRefresh: () async {
                  ref.invalidate(storeModelProvider);
                  await _currentModel();
                },
                child: CustomScrollView(slivers: slivers),
              ),
              if (_busy)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: AppTheme.lime,
                    backgroundColor: Colors.transparent,
                  ),
                ),
            ],
          ),
        ),
        _BottomBar(
          unplaced: model.unplaced.length,
          onInventory: () => _browseInventory(model),
          onCreate: () {
            if (_canEdit(model)) {
              createProductFlow(context, ref, layout: layout);
            }
          },
        ),
      ],
    );
  }

  List<Widget> _searchResults(
    StoreModel model,
    StoreLayout layout,
    String query,
  ) {
    bool matches(StoreProduct product) => normalizeForSearch(
      '${_nameOf(product)} ${product.category}',
    ).contains(query);
    final results = [
      for (final product in model.metadata.products)
        if (matches(product)) product,
      for (final product in model.unplaced)
        if (matches(product)) product,
    ];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Text(
            '${results.length} ${results.length == 1 ? 'resultado' : 'resultados'}',
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        sliver: SliverList.separated(
          itemCount: results.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final product = results[index];
            final place = _placeOfProduct(layout, product);
            return ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                side: const BorderSide(color: AppTheme.border, width: 1.5),
              ),
              contentPadding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
              title: Text(
                _nameOf(product),
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                place ?? 'En el inventario, sin estante',
                style: TextStyle(
                  color: place == null ? AppTheme.muted : AppTheme.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Icon(
                place == null
                    ? Icons.add_location_alt_outlined
                    : Icons.chevron_right_rounded,
                color: AppTheme.green,
              ),
              onTap: () {
                if (place == null) {
                  if (_canEdit(model)) _startPlacement(product);
                } else {
                  _focus(product.slotId);
                }
              },
            );
          },
        ),
      ),
    ];
  }
}

/// Cabecera `night`: sucursal, resumen del plano, usuarios y menú.
class _Header extends StatelessWidget {
  const _Header({
    required this.store,
    required this.layout,
    required this.onMenu,
  });

  final Supermarket store;
  final StoreLayout? layout;
  final ValueChanged<_MenuAction> onMenu;

  @override
  Widget build(BuildContext context) {
    final layout = this.layout;
    final numbered = layout?.aisles.where((a) => a.number != null).length ?? 0;
    final zones = (layout?.aisles.length ?? 0) - numbered;
    return Container(
      color: AppTheme.night,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 12, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PLANO DE LA TIENDA',
                      style: TextStyle(
                        color: AppTheme.lime,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      store.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (layout != null)
                      // Dos líneas fijas: no se cortan a mitad de un dato.
                      Text(
                        '$numbered pasillos · $zones zonas\n'
                        '${layout.slotCount} espacios · '
                        '${layout.freeCount} ${layout.freeCount == 1 ? 'libre' : 'libres'}',
                        maxLines: 2,
                        style: const TextStyle(
                          color: AppTheme.onNightMuted,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                  ],
                ),
              ),
              SmSquareButton(
                icon: Icons.group_outlined,
                tooltip: 'Usuarios',
                dark: true,
                onPressed: () => context.pushNamed('users'),
              ),
              PopupMenuButton<_MenuAction>(
                tooltip: 'Más opciones',
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onSelected: onMenu,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _MenuAction.map3d,
                    child: ListTile(
                      leading: Icon(Icons.view_in_ar_outlined),
                      title: Text('Ver mapa 3D'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.staff,
                    child: ListTile(
                      leading: Icon(Icons.admin_panel_settings_outlined),
                      title: Text('Panel de administración'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.refresh,
                    child: ListTile(
                      leading: Icon(Icons.refresh_rounded),
                      title: Text('Actualizar'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.logout,
                    child: ListTile(
                      leading: Icon(Icons.logout_rounded),
                      title: Text('Cerrar sesión'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AisleHeader extends StatelessWidget {
  const _AisleHeader({required this.aisle});

  final LayoutAisle aisle;

  @override
  Widget build(BuildContext context) {
    final categories = aisle.categories();
    final free = aisle.freeCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              aisle.label,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (categories.isNotEmpty)
            Text(
              categories.join(' · '),
              style: const TextStyle(color: AppTheme.green, fontSize: 15),
            ),
          Text(
            '${aisle.shelves.length} ${aisle.shelves.length == 1 ? 'estante' : 'estantes'} · '
            '${aisle.slotCount} espacios'
            '${free == 0 ? '' : ' · $free ${free == 1 ? 'libre' : 'libres'}'}',
            style: const TextStyle(color: AppTheme.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.unplaced,
    required this.onInventory,
    required this.onCreate,
  });

  final int unplaced;
  final VoidCallback onInventory;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onInventory,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.inventory_2_outlined, size: 22),
                  label: _OneLine(
                    unplaced == 0 ? 'Inventario' : 'Inventario ($unplaced)',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCreate,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 22),
                  label: const _OneLine('Crear producto'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta de botón en una sola línea: si no cabe, se achica un poco en vez
/// de partirse en dos.
class _OneLine extends StatelessWidget {
  const _OneLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, softWrap: false),
    );
  }
}

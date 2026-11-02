import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../app/providers/store_providers.dart';
import '../../domain/entities/store_model.dart';
import '../../domain/services/store_route_planner.dart';
import '../providers/store_model_provider.dart';
import '../widgets/store_edit_sheets.dart';
import '../widgets/supermarket_viewport.dart';

/// Nodo de acceso del supermercado, donde empieza el avatar y las rutas.
String startNodeOf(StoreModel model) => model.metadata.routeNodes
    .firstWhere(
      (node) => RegExp(
        r'acceso|entrada|inicio',
        caseSensitive: false,
      ).hasMatch(node.id),
      orElse: () => model.metadata.routeNodes.first,
    )
    .id;

/// Estado y acciones del modo de edición de la tienda (solo administradores).
class StoreEditController extends ChangeNotifier {
  StoreEditController({
    required this.ref,
    required this.viewport,
    required this.onAisleView,
  });

  final WidgetRef ref;
  final SupermarketViewportState? Function() viewport;
  final VoidCallback onAisleView;

  bool editing = false;
  bool busy = false;
  StoreProduct? carrying;
  String _avatarNode = '';
  bool _disposed = false;

  BuildContext get _context => ref.context;
  bool get _mounted => !_disposed && _context.mounted;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void toggle(StoreModel model) {
    if (model.metadata.routeNodes.isEmpty) return;
    editing = !editing;
    carrying = null;
    _avatarNode = startNodeOf(model);
    notifyListeners();
    ref.read(navigationSessionProvider.notifier).clear();
    viewport()?.setEditMode(editing, _avatarNode);
    viewport()?.carry(false);
    if (editing) onAisleView();
  }

  void dropCarry() {
    carrying = null;
    notifyListeners();
    viewport()?.carry(false);
  }

  void _toast(String message) => ScaffoldMessenger.of(
    _context,
  ).showSnackBar(SnackBar(content: Text(message)));

  /// El avatar camina hasta la caja tocada y se ofrecen las acciones de ese espacio.
  Future<void> onSlotTapped(StoreModel model, String boxId) async {
    if (busy) return;
    final occupied = model.metadata.products
        .where((p) => p.id == boxId)
        .firstOrNull;
    final box =
        occupied ?? model.emptySlots.where((p) => p.id == boxId).firstOrNull;
    if (box == null) return;
    busy = true;
    notifyListeners();
    try {
      await _walkTo(model, box);
      if (!_mounted) return;
      viewport()?.selectProduct(box.id);
      final action = await showSlotActions(
        _context,
        product: occupied,
        carrying: carrying,
      );
      if (!_mounted || action == null) return;
      await _runSlotAction(action, box, occupied);
    } finally {
      if (_mounted) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> _walkTo(StoreModel model, StoreProduct box) async {
    if (box.routeNode.isEmpty || _avatarNode.isEmpty) return;
    List<String> path;
    try {
      path = const StoreRoutePlanner()
          .plan(
            routeNodes: model.metadata.routeNodes,
            products: [...model.metadata.products, ...model.emptySlots],
            startNodeId: _avatarNode,
            productIds: [box.id],
          )
          .nodeIds;
    } on StateError {
      path = [box.routeNode];
    }
    await viewport()?.walkAvatar(path);
    _avatarNode = box.routeNode;
  }

  Future<void> _runSlotAction(
    SlotAction action,
    StoreProduct box,
    StoreProduct? occupied,
  ) async {
    final api = ref.read(catalogApiProvider);
    try {
      switch (action) {
        case SlotAction.pickUp:
          carrying = occupied;
          notifyListeners();
          viewport()?.carry(true);
          _toast('Llevas "${occupied!.name}". Toca otro espacio para dejarlo.');
        case SlotAction.drop:
          final carried = carrying!;
          await api.moveSlot(carried.slotId, box.slotId);
          carrying = null;
          notifyListeners();
          viewport()?.carry(false);
          ref.invalidate(storeModelProvider);
          _toast(
            occupied == null
                ? '"${carried.name}" se movió.'
                : '"${carried.name}" y "${occupied.name}" se intercambiaron.',
          );
        case SlotAction.edit:
          final form = await showProductForm(
            _context,
            title: 'Editar producto',
            name: occupied!.name,
            price: occupied.price,
            stock: occupied.stock,
          );
          if (form == null) return;
          await api.updateProduct(
            occupied.dbId!,
            name: form.name,
            price: form.price,
            stock: form.stock,
          );
          ref.invalidate(storeModelProvider);
          _toast('Cambios guardados.');
        case SlotAction.remove:
          await _removeProduct(occupied!);
        case SlotAction.create:
          final categories = await api.loadCategories();
          if (!_mounted) return;
          final form = await showProductForm(
            _context,
            title: 'Producto nuevo',
            categories: categories,
          );
          if (form == null) return;
          await api.createInSlot(
            box.slotId,
            name: form.name,
            price: form.price,
            stock: form.stock,
            categoryId: form.categoryId!,
          );
          ref.invalidate(storeModelProvider);
          _toast('"${form.name}" se agregó a la sucursal.');
      }
    } on Object catch (error) {
      _toast(
        error is http.ClientException
            ? error.message
            : 'No se pudo guardar el cambio.',
      );
    }
  }

  Future<void> _removeProduct(StoreProduct product) async {
    final messenger = ScaffoldMessenger.of(_context);
    final confirmed = await showDialog<bool>(
      context: _context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar producto'),
        content: Text(
          '¿Quitar "${product.name}" de la sucursal? '
          'Se eliminará su stock y ubicación en la base de datos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !_mounted) return;
    try {
      await ref.read(catalogApiProvider).removeProduct(product.dbId!);
      ref.invalidate(storeModelProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('"${product.name}" se quitó de la sucursal.')),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is http.ClientException
                ? error.message
                : 'No se pudo quitar el producto.',
          ),
        ),
      );
    }
  }
}

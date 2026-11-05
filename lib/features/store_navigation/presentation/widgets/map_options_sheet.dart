import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/store_model.dart';
import 'store_segments.dart';

sealed class MapAction {
  const MapAction();
}

class SelectStoreAction extends MapAction {
  const SelectStoreAction(this.store);

  final Supermarket store;
}

class PickRouteAction extends MapAction {
  const PickRouteAction();
}

class OpenUsersAction extends MapAction {
  const OpenUsersAction();
}

class ToggleEditAction extends MapAction {
  const ToggleEditAction();
}

/// Herramientas del mapa que no aparecen en el diseño principal: cambio de

class MapOptionsSheet extends StatelessWidget {
  const MapOptionsSheet({
    super.key,
    required this.store,
    required this.panWithOneFinger,
    required this.showNodes,
    required this.showMetrics,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onTopView,
    required this.onAisleView,
    required this.onReset,
    required this.onToggleMode,
    required this.onToggleNodes,
    required this.onToggleMetrics,
    required this.isAdmin,
    required this.storeLocked,
    required this.editing,
  });

  final bool isAdmin;
  final bool editing;
  final bool storeLocked;
  final Supermarket store;
  final bool panWithOneFinger;
  final bool showNodes;
  final bool showMetrics;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onTopView;
  final VoidCallback onAisleView;
  final VoidCallback onReset;
  final VoidCallback onToggleMode;
  final VoidCallback onToggleNodes;
  final VoidCallback onToggleMetrics;

  @override
  Widget build(BuildContext context) {
    const sectionStyle = TextStyle(
      color: AppTheme.ink,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!storeLocked) ...[
              const Text('Supermercado', style: sectionStyle),
              const SizedBox(height: 10),
              StoreSegments(
                store: store,
                onChanged: (value) =>
                    Navigator.pop(context, SelectStoreAction(value)),
              ),
              const SizedBox(height: 20),
            ],
            const Text('Cámara', style: sectionStyle),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ToolButton(Icons.add, 'Acercar', onZoomIn),
                _ToolButton(Icons.remove, 'Alejar', onZoomOut),
                _ToolButton(
                  Icons.rotate_left,
                  'Girar a la izquierda',
                  onRotateLeft,
                ),
                _ToolButton(
                  Icons.rotate_right,
                  'Girar a la derecha',
                  onRotateRight,
                ),
                _ToolButton(Icons.map_outlined, 'Vista superior', onTopView),
                _ToolButton(
                  Icons.directions_walk,
                  'Vista de pasillo',
                  onAisleView,
                ),
                _ToolButton(Icons.center_focus_strong, 'Centrar mapa', onReset),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Un dedo desplaza el mapa'),
              subtitle: const Text('Si está apagado, un dedo gira la cámara'),
              value: panWithOneFinger,
              onChanged: (_) => onToggleMode(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar nodos de ruta'),
              value: showNodes,
              onChanged: (_) => onToggleNodes(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Rendimiento 3D'),
              value: showMetrics,
              onChanged: (_) => onToggleMetrics(),
            ),
            const Divider(height: 24),
            if (!isAdmin)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_road),
                title: const Text('Armar mi ruta'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, const PickRouteAction()),
              ),
            if (isAdmin) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_location_alt_outlined),
                title: Text(editing ? 'Terminar edición' : 'Editar tienda'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, const ToggleEditAction()),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.people_outline),
                title: const Text('Usuarios'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, const OpenUsersAction()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton(this.icon, this.tooltip, this.onPressed);

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: AppTheme.ink),
      style: IconButton.styleFrom(
        side: const BorderSide(color: AppTheme.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(48, 48),
      ),
    );
  }
}

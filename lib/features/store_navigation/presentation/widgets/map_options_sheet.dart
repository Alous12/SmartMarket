import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/section_label.dart';
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

class OpenStaffAction extends MapAction {
  const OpenStaffAction();
}

class ToggleEditAction extends MapAction {
  const ToggleEditAction();
}

/// Herramientas del mapa que no aparecen en el diseño principal: cambio de
/// sucursal, cámara, ajustes del mapa y accesos según el rol.

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
    // Los ajustes de desarrollo solo los ven el admin o una compilación de depuración.
    final showDeveloperTools = isAdmin || kDebugMode;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Opciones del mapa',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (!storeLocked) ...[
              const SectionLabel('Supermercado'),
              const SizedBox(height: 10),
              StoreSegments(
                store: store,
                onChanged: (value) =>
                    Navigator.pop(context, SelectStoreAction(value)),
              ),
              const SizedBox(height: 24),
            ],
            const SectionLabel('Cámara'),
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
            const SizedBox(height: 24),
            const SectionLabel('Mapa'),
            const SizedBox(height: 4),
            _SwitchRow(
              title: 'Un dedo desplaza el mapa',
              subtitle: 'Si está apagado, un dedo gira la cámara',
              value: panWithOneFinger,
              onChanged: onToggleMode,
            ),
            if (showDeveloperTools) ...[
              _SwitchRow(
                title: 'Mostrar nodos de ruta',
                value: showNodes,
                onChanged: onToggleNodes,
              ),
              _SwitchRow(
                title: 'Rendimiento 3D',
                value: showMetrics,
                onChanged: onToggleMetrics,
              ),
            ],
            const SizedBox(height: 16),
            if (!isAdmin)
              _ActionRow(
                icon: Icons.add_road,
                title: 'Armar mi ruta',
                onTap: () => Navigator.pop(context, const PickRouteAction()),
              ),
            if (isAdmin) ...[
              const SectionLabel('Administración'),
              const SizedBox(height: 8),
              _ActionRow(
                icon: Icons.edit_location_alt_outlined,
                title: editing ? 'Terminar edición' : 'Editar tienda',
                onTap: () => Navigator.pop(context, const ToggleEditAction()),
              ),
              _ActionRow(
                icon: Icons.people_outline,
                title: 'Usuarios',
                onTap: () => Navigator.pop(context, const OpenUsersAction()),
              ),
              _ActionRow(
                icon: Icons.inventory_outlined,
                title: 'Panel de administración',
                onTap: () => Navigator.pop(context, const OpenStaffAction()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: Colors.white,
      activeTrackColor: AppTheme.green,
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.ink,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
      value: value,
      onChanged: (_) => onChanged(),
    );
  }
}

/// Acceso con icono en un cuadro tintado.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusS),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.tint,
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Icon(icon, color: AppTheme.green, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.muted),
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
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppTheme.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        minimumSize: const Size(52, 52),
      ),
    );
  }
}

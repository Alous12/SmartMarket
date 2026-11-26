import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/store_model.dart';

/// Selector de sucursal: contenedor blanco con el segmento activo en verde.
class StoreSegments extends StatelessWidget {
  const StoreSegments({
    super.key,
    required this.store,
    required this.onChanged,
  });

  final Supermarket store;
  final ValueChanged<Supermarket> onChanged;

  @override
  Widget build(BuildContext context) {
    final duration = AppTheme.motion(context, AppTheme.fast);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          for (final option in Supermarket.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: option == store,
                inMutuallyExclusiveGroup: true,
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: option == store ? AppTheme.green : Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.radiusL),
                      onTap: option == store ? null : () => onChanged(option),
                      child: SizedBox(
                        height: 52,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: AnimatedDefaultTextStyle(
                                duration: duration,
                                style: TextStyle(
                                  color: option == store
                                      ? Colors.white
                                      : AppTheme.ink,
                                  fontSize: 16,
                                  fontWeight: option == store
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                ),
                                child: Text(
                                  option.shortTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

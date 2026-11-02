import 'package:flutter/material.dart';

import '../../domain/entities/store_model.dart';

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
    return SegmentedButton<Supermarket>(
      showSelectedIcon: false,
      segments: [
        for (final option in Supermarket.values)
          ButtonSegment(
            value: option,
            icon: Icon(
              option == Supermarket.natural
                  ? Icons.storefront_outlined
                  : Icons.store_mall_directory_outlined,
            ),
            label: Text(option.shortTitle),
          ),
      ],
      selected: {store},
      onSelectionChanged: (selection) => onChanged(selection.single),
    );
  }
}

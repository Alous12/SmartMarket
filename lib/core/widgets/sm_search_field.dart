import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Campo de búsqueda de 52 de alto con lupa.
class SmSearchField extends StatelessWidget {
  const SmSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.controller,
    this.autofocus = false,
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      borderSide: const BorderSide(color: AppTheme.border),
    );
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 16, color: AppTheme.ink),
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search, color: AppTheme.muted),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: AppTheme.green, width: 2),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Borde redondeado que no abre hueco para la etiqueta: la etiqueta visible va
/// encima del campo, como en el diseño.
class _FieldBorder extends OutlineInputBorder {
  const _FieldBorder({super.borderSide, super.borderRadius});

  @override
  _FieldBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) => _FieldBorder(
    borderSide: borderSide ?? this.borderSide,
    borderRadius: borderRadius ?? this.borderRadius,
  );

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) => super.paint(canvas, rect, textDirection: textDirection);
}

/// Campo del diseño: etiqueta en negrita encima, caja blanca de 56 de alto,
/// radio 16, borde verde de 2 y halo lima al enfocar.
///
/// La etiqueta también vive dentro del campo (invisible) para que lectores de
/// pantalla y pruebas lo encuentren por su nombre.
class SmTextField extends StatefulWidget {
  const SmTextField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.validator,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onFieldSubmitted,
    this.onChanged,
    this.suffix,
    this.prefix,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.inputFormatters,
    this.errorText,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final Widget? prefix;
  final int? maxLength;
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final bool autofocus;

  @override
  State<SmTextField> createState() => _SmTextFieldState();
}

class _SmTextFieldState extends State<SmTextField> {
  bool _focused = false;

  static const _radius = BorderRadius.all(Radius.circular(AppTheme.radiusM));

  @override
  Widget build(BuildContext context) {
    const hidden = TextStyle(
      fontSize: 1,
      height: 0.01,
      color: Colors.transparent,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            widget.label,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (value) => setState(() => _focused = value),
          child: AnimatedContainer(
            duration: AppTheme.motion(context, AppTheme.fast),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(19)),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: AppTheme.lime.withValues(alpha: 0.55),
                        spreadRadius: 3.5,
                      ),
                    ]
                  : const [],
            ),
            child: TextFormField(
              controller: widget.controller,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              textCapitalization: widget.textCapitalization,
              autofillHints: widget.autofillHints,
              onFieldSubmitted: widget.onFieldSubmitted,
              onChanged: widget.onChanged,
              validator: widget.validator,
              maxLength: widget.maxLength,
              textAlign: widget.textAlign,
              inputFormatters: widget.inputFormatters,
              style: const TextStyle(fontSize: 17, color: AppTheme.ink),
              decoration: InputDecoration(
                labelText: widget.label,
                labelStyle: hidden,
                floatingLabelStyle: hidden,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintText: widget.hintText,
                hintStyle: const TextStyle(color: AppTheme.muted, fontSize: 17),
                errorText: widget.errorText,
                errorStyle: const TextStyle(
                  color: AppTheme.danger,
                  fontSize: 14,
                ),
                counterText: '',
                suffixIcon: widget.suffix,
                prefixIcon: widget.prefix,
                filled: true,
                fillColor: Colors.white,
                isDense: false,
                contentPadding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
                border: const _FieldBorder(
                  borderRadius: _radius,
                  borderSide: BorderSide(color: Color(0xFFDDE1D8), width: 1.5),
                ),
                enabledBorder: const _FieldBorder(
                  borderRadius: _radius,
                  borderSide: BorderSide(color: Color(0xFFDDE1D8), width: 1.5),
                ),
                disabledBorder: const _FieldBorder(
                  borderRadius: _radius,
                  borderSide: BorderSide(color: AppTheme.border, width: 1.5),
                ),
                focusedBorder: const _FieldBorder(
                  borderRadius: _radius,
                  borderSide: BorderSide(color: AppTheme.green, width: 2),
                ),
                errorBorder: const _FieldBorder(
                  borderRadius: _radius,
                  borderSide: BorderSide(color: AppTheme.danger, width: 2),
                ),
                focusedErrorBorder: const _FieldBorder(
                  borderRadius: _radius,
                  borderSide: BorderSide(color: AppTheme.danger, width: 2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

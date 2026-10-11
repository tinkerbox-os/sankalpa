import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sankalpa/widgets/native_web_text_field_stub.dart'
    if (dart.library.js_interop) 'package:sankalpa/widgets/native_web_text_field_web.dart'
    as impl;

/// Text field that uses a real DOM input on Flutter web.
///
/// iOS home-screen (standalone) PWAs often fail to open the software keyboard
/// for Flutter's canvas [TextField] and for [HtmlElementView] inputs (the
/// glass pane steals user-activation). Web uses a `document.body` overlay
/// input positioned over a Flutter placeholder instead.
///
/// Non-web platforms fall back to a normal [TextFormField].
class NativeWebTextField extends StatelessWidget {
  const NativeWebTextField({
    required this.controller,
    super.key,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.autocorrect = true,
    this.enabled = true,
    this.maxLength,
    this.inputFormatters,
    this.onFieldSubmitted,
    this.validator,
    this.decoration,
    this.style,
    this.cursorColor,
    this.textAlign = TextAlign.start,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final bool enabled;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;
  final InputDecoration? decoration;
  final TextStyle? style;
  final Color? cursorColor;
  final TextAlign textAlign;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        autocorrect: autocorrect,
        enabled: enabled,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        cursorColor: cursorColor,
        style: style,
        textAlign: textAlign,
        obscureText: obscureText,
        decoration: decoration,
      );
    }
    return impl.NativeWebTextFieldView(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      autocorrect: autocorrect,
      enabled: enabled,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      decoration: decoration,
      style: style,
      textAlign: textAlign,
      obscureText: obscureText,
    );
  }
}

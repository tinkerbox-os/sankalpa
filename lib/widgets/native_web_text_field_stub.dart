import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Non-web stub — NativeWebTextField never calls this on VM/mobile.
class NativeWebTextFieldView extends StatelessWidget {
  const NativeWebTextFieldView({
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
  final TextAlign textAlign;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    throw UnsupportedError('NativeWebTextFieldView is web-only');
  }
}

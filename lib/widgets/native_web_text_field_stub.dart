import 'package:flutter/widgets.dart';

/// Non-web stub: returns the child unmodified.
class NativeWebTextField extends StatelessWidget {
  const NativeWebTextField({
    required this.child,
    required this.controller,
    super.key,
    this.inputType = 'text',
    this.inputMode,
    this.placeholder = '',
    this.maxLength,
    this.autocomplete,
    this.textAlign = 'start',
    this.onSubmitted,
  });

  final Widget child;
  final TextEditingController controller;
  final String inputType;
  final String? inputMode;
  final String placeholder;
  final int? maxLength;
  final String? autocomplete;
  final String textAlign;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => child;
}

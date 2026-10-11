import 'package:flutter/widgets.dart';

/// Non-web stub: returns the child unmodified.
class WebTapOverlay extends StatelessWidget {
  const WebTapOverlay({
    required this.child,
    required this.onTap,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => child;
}

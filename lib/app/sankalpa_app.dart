import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sankalpa/app/router.dart';
import 'package:sankalpa/app/theme/sankalpa_theme.dart';

/// Root widget for Sankalpa.
class SankalpaApp extends ConsumerWidget {
  const SankalpaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Sankalpa',
      debugShowCheckedModeBanner: false,
      theme: SankalpaTheme.light(),
      darkTheme: SankalpaTheme.dark(),
      routerConfig: router,
    );
  }
}

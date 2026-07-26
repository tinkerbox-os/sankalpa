import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/widgets/card_ambient_decoration.dart';

/// Renders every card theme as it actually paints — background, ambient
/// decoration and vignette — on the light app scaffold, so the palette can be
/// eyeballed as a whole. Regenerate with:
///
///   flutter test --update-goldens test/palette_preview_test.dart
void main() {
  testWidgets('card palette preview', (tester) async {
    tester.view
      ..physicalSize = const Size(720, 1180)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: CreamPalette.bg,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                for (final t in CardBackdropTheme.values)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.md),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: t.bg),
                        Positioned.fill(
                          child: CardAmbientDecoration(
                            kind: t.decoration,
                            color: t.text,
                            intensity: 0.9,
                          ),
                        ),
                        Positioned.fill(
                          child: CardVignette(
                            dark: t.bg.computeLuminance() < 0.5,
                          ),
                        ),
                        Center(
                          child: Text(
                            t.label,
                            style: TextStyle(color: t.text, fontSize: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // The decoration animates continuously, so settle a fixed number of
    // frames rather than pumpAndSettle, which would never return.
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(GridView),
      matchesGoldenFile('goldens/card_palette.png'),
    );
  });
}

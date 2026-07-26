import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sankalpa/app/sankalpa_app.dart';

void main() {
  testWidgets('SankalpaApp boots and renders the Today screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SankalpaApp(),
      ),
    );
    // Not `pumpAndSettle`: the Today screen's `CardAmbientDecoration` drives a
    // free-running Ticker for its drifting sparkles, so a frame is always
    // scheduled and the tree never settles. A couple of bounded pumps are
    // enough to get past first layout.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sankalpa'), findsWidgets);

    // Tests run without `--dart-define=SUPABASE_URL`, so the app boots in its
    // unconfigured state: the banner shows and cloud-backed sections are
    // skipped.
    expect(find.text('Supabase not configured.'), findsOneWidget);
    expect(
      find.text('Take a moment for your manifestations.'),
      findsOneWidget,
    );
    expect(find.text('Start ritual'), findsOneWidget);
  });
}

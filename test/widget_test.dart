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
    await tester.pumpAndSettle();

    expect(find.text('Sankalpa'), findsWidgets);
    expect(find.text('Your daily ritual'), findsOneWidget);
  });
}

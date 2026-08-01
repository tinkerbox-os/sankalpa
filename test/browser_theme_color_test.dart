import 'package:flutter_test/flutter_test.dart';
import 'package:sankalpa/app/platform/browser_theme_color.dart';
import 'package:sankalpa/app/platform/browser_theme_color_record.dart';

void main() {
  setUp(BrowserThemeColorRecord.reset);
  tearDown(BrowserThemeColorRecord.reset);

  test('edgeTints true marks chrome tint strips as active', () {
    setBrowserThemeColor('#7A8B6F', edgeTints: true);

    expect(BrowserThemeColorRecord.calls, hasLength(1));
    expect(BrowserThemeColorRecord.calls.single.edgeTints, isTrue);
    expect(BrowserThemeColorRecord.calls.single.cssColor, '#7A8B6F');
    expect(
      BrowserThemeColorRecord.activeTintIds,
      unorderedEquals(BrowserChromeTintIds.all),
    );
  });

  test('edgeTints false clears chrome tint strips', () {
    setBrowserThemeColor('#7A8B6F', edgeTints: true);
    setBrowserThemeColor('#F5F0E8');

    expect(BrowserThemeColorRecord.calls, hasLength(2));
    expect(BrowserThemeColorRecord.calls.last.edgeTints, isFalse);
    expect(BrowserThemeColorRecord.activeTintIds, isEmpty);
  });

  test('edgeTints defaults to false so sign-in never keeps strips', () {
    setBrowserThemeColor('#ABCDEF');

    expect(BrowserThemeColorRecord.calls.single.edgeTints, isFalse);
    expect(BrowserThemeColorRecord.activeTintIds, isEmpty);
  });
}

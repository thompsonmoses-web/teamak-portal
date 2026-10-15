import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamak_app/app.dart';

/// The landing page targets a desktop-width screen, so give tests a roomy
/// surface. Without this the hero actions sit below the fold and taps miss.
void useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Scrolls the landing page's main list, which is one of several [Scrollable]s
/// on the page (the showcase slideshow is a [PageView], and the earnings
/// calculator adds sliders). `scrollUntilVisible` resolves its scrollable with
/// `.single`, so it must be pinned explicitly.
Future<void> scrollLanding(
  WidgetTester tester,
  FinderBase<Element> target,
) =>
    tester.scrollUntilVisible(
      target,
      400,
      scrollable: find.byType(Scrollable).first,
    );

void main() {
  testWidgets('landing page shows the three ownership tiers', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(const TeamakApp());
    // The tier cards render only once /programmes has failed and the static
    // fallback list takes over, so let that round-trip complete.
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Start application'), findsWidgets);

    // The landing list builds lazily, so off-screen sections are not in the
    // tree yet. Scroll the first tier card into view before asserting. The
    // deposit labels are exact-match unique; the surrounding summaries contain
    // the same figures, so we match on full text rather than textContaining.
    await scrollLanding(tester, find.text('₦650,000'));
    expect(find.text('₦650,000'), findsOneWidget);
    expect(find.text('₦400,000'), findsOneWidget);
    expect(find.text('₦2,300,000'), findsOneWidget);
    expect(find.text('Apply for this'), findsNWidgets(3));

    await scrollLanding(
      tester,
      find.text('Ride with Dignity. Own Your Future.'),
    );
    expect(
      find.text('Ride with Dignity. Own Your Future.'),
      findsOneWidget,
    );
  });

  testWidgets('apply wizard starts at step 1', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(const TeamakApp());
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Start application').first);
    // Drive the route transition by hand rather than pumpAndSettle, which the
    // landing page's ambient animations would keep busy.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('STEP 1 OF 4'), findsOneWidget);
    expect(find.text('About you'), findsWidgets);
  });
}

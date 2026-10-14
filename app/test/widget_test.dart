import 'package:flutter_test/flutter_test.dart';
import 'package:teamak_app/app.dart';

void main() {
  testWidgets('landing page shows the three ownership tiers', (tester) async {
    await tester.pumpWidget(const TeamakApp());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Teamak Rider Ownership Programme'), findsOneWidget);
    expect(find.textContaining('Start application'), findsWidgets);
    expect(find.textContaining('₦650,000'), findsWidgets);
    expect(find.textContaining('₦400,000'), findsWidgets);
    expect(find.textContaining('₦2,300,000'), findsWidgets);

    await tester.scrollUntilVisible(
      find.textContaining('Ride with Dignity'),
      400,
    );
    expect(find.textContaining('Ride with Dignity. Own Your Future.'), findsOneWidget);
  });

  testWidgets('apply wizard starts at step 1', (tester) async {
    await tester.pumpWidget(const TeamakApp());
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Start application').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Step 1 of 8'), findsOneWidget);
    expect(find.text('About you'), findsWidgets);
  });
}

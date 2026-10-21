import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teamak_app/app.dart';

import 'support/overflow.dart';

void main() {
  setUp(() {
    // The shell restores sessions from storage on boot; an empty store is
    // all this page needs.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpFaq(WidgetTester tester, {double width = 800}) async {
    // Tall enough that the whole accordion builds: ListView children
    // outside the viewport are never laid out, so finders would miss the
    // questions below the fold.
    tester.view.physicalSize = Size(width, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TeamakApp(initialPath: '/faq'));
    await tester.pumpAndSettle();
  }

  testWidgets('the support centre leads with its trust strip', (tester) async {
    await pumpFaq(tester);

    expect(find.text('Questions, answered clearly'), findsOneWidget);
    expect(find.text('Frequently asked questions'), findsOneWidget);
    expect(find.text('₦0'), findsOneWidget);
    expect(find.text('Application fee'), findsOneWidget);
    expect(find.text('RC 9907312'), findsOneWidget);
    expect(find.text('Registered company'), findsOneWidget);
    expect(find.text('Apply for a slot'), findsWidgets);
  });

  testWidgets('a category filter narrows the questions', (tester) async {
    await pumpFaq(tester);

    expect(find.text('How do I apply for a slot?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Verification'));
    await tester.pumpAndSettle();

    expect(
      find.text('How do I apply for a slot?'),
      findsNothing,
      reason: 'an Applying question should hide under the Verification tab',
    );
    expect(find.text('What happens after I submit?'), findsOneWidget);
    expect(find.text('Why do you check originals?'), findsOneWidget);
  });

  testWidgets('Show all questions restores every topic', (tester) async {
    await pumpFaq(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Ownership'));
    await tester.pumpAndSettle();
    expect(find.text('How do I apply for a slot?'), findsNothing);

    await tester.tap(find.text('Show all questions'));
    await tester.pumpAndSettle();
    expect(find.text('How do I apply for a slot?'), findsOneWidget);
  });

  testWidgets('a question opens its answer on tap', (tester) async {
    await pumpFaq(tester);

    await tester.tap(find.text('How do I apply for a slot?'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('fill the form'),
      findsOneWidget,
      reason: 'the accordion should reveal the answer text',
    );
    expect(flexOverflows(tester), isEmpty);
  });

  testWidgets('an open question still fits a 320px screen', (tester) async {
    await pumpFaq(tester, width: 320);

    await tester.tap(find.text('How do I apply for a slot?'));
    await tester.pumpAndSettle();

    expect(find.textContaining('fill the form'), findsOneWidget);
    expect(
      flexOverflows(tester),
      isEmpty,
      reason: 'an expanded accordion on the smallest phone width',
    );
  });

  testWidgets('the support card answers with WhatsApp and contact',
      (tester) async {
    await pumpFaq(tester);

    expect(find.text('Still have questions?'), findsOneWidget);
    expect(find.text('Chat on WhatsApp'), findsOneWidget);
    expect(find.text('Contact us'), findsOneWidget);
    expect(
      find.text('Every decision recorded'),
      findsOneWidget,
      reason: 'the commitment cards should back the answers',
    );
  });
}

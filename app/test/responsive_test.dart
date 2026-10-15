import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamak_app/app.dart';

import 'support/fields.dart';

/// Collects the text painted inside [node]'s subtree.
///
/// Rendered copy is what makes an overflow report actionable: the framework
/// gives sizes but not which label overflowed.
String _textOf(RenderObject node) {
  final out = <String>[];
  void walk(RenderObject n) {
    if (n is RenderParagraph) out.add('"${n.text.toPlainText()}"');
    n.visitChildren(walk);
  }

  walk(node);
  return out.join(' + ');
}

/// Finds every horizontal RenderFlex whose children extend past its own width.
///
/// Walking the render tree beats catching the framework's overflow assertion:
/// that report names only the first offender and truncates its ancestor chain,
/// so a page with several overflows needs one pass to surface all of them.
Set<String> flexOverflows(WidgetTester tester) {
  final hits = <String>{};

  void walk(RenderObject node) {
    // Children outside the viewport are kept but not laid out; asking such a
    // box for its size throws, and it has no geometry to compare anyway.
    if (node is! RenderBox || !node.hasSize) {
      node.visitChildren(walk);
      return;
    }
    if (node is RenderFlex && node.size.width > 0) {
      var extent = 0.0;
      node.visitChildren((raw) {
        if (raw is! RenderBox || !raw.hasSize) return;
        final parentData = raw.parentData;
        if (parentData is! BoxParentData) return;
        final right = parentData.offset.dx + raw.size.width;
        if (extent < right) extent = right;
      });
      if (extent > node.size.width + 0.5) {
        hits.add(
          'overflows by ${(extent - node.size.width).toStringAsFixed(0)}px '
          '(needs ${extent.toStringAsFixed(0)} of '
          '${node.size.width.toStringAsFixed(0)}) — ${_textOf(node)}',
        );
      }
    }
    node.visitChildren(walk);
  }

  walk(tester.renderObject(find.byType(MaterialApp)));
  return hits;
}

/// Types into the first field carrying [label], if the current step has one.
Future<void> _fill(WidgetTester tester, String label, String value,
        {int index = 0}) async =>
    fillField(tester, label, value, index: index);

/// Taps the first option carrying [label] that is on screen.
Future<void> _choose(WidgetTester tester, String label, {int index = 0}) async =>
    tapOption(tester, label, index: index);

/// Answers the current wizard step so `Continue` passes validation.
///
/// Without this the walk stalls on step one: an untouched form fails
/// `validate()` and the overflow sweep would never see sections D, E or G.
Future<void> _completeStep(WidgetTester tester, int step) async {
  switch (step) {
    case 0:
      await _fill(tester, 'Full name *', 'Adebayo Ogundele');
      await _fill(tester, 'Phone number *', '08023449126');
      await _fill(tester, 'Residential address *', '12 Ojoo Road, Ibadan');
      await _fill(tester, 'Area / community *', 'Ojoo');
      await _fill(tester, 'Date of birth *', '1990-05-14');
      await _fill(tester, 'NIN *', '12345678901');
      await _choose(tester, 'Single');
    case 1:
      await _choose(tester, 'Okada (motorcycle)');
      await _choose(tester, '4–6 years');
      await _choose(tester, 'Owned by me');
      await _fill(tester, 'Park / route / operating area *', 'Ojoo - UI Gate');
      await _fill(tester, 'Park association name *', 'Ojoo Okada Park');
      await _fill(tester, 'Current daily remittance *', '1,500 Naira daily');
      await _fill(tester, 'Working days per week *', '6');
    case 2:
      await _choose(tester, 'OKADA OWNERSHIP');
    case 3:
      await _choose(tester, 'Personal savings');
      final deposit = DateTime.now().add(const Duration(days: 30));
      await _fill(
        tester,
        'Expected deposit date *',
        '${deposit.year.toString().padLeft(4, '0')}-'
        '${deposit.month.toString().padLeft(2, '0')}-'
        '${deposit.day.toString().padLeft(2, '0')}',
      );
      await _choose(tester, 'No');
    case 4:
      // Every document question must be answered to advance.
      for (var i = 0; i < 5; i++) {
        await _choose(tester, 'Yes', index: i);
      }
    case 5:
      await _fill(tester, 'Next of kin name *', 'Folake Ogundele');
      await _fill(tester, 'Next of kin phone *', '08031234567');
      await _fill(tester, 'Relationship *', 'Wife');
      await _fill(tester, 'Next of kin address *', '12 Ojoo Road, Ibadan');
      await _fill(tester, 'Full name *', 'Sunday Adeyemi', index: 0);
      await _fill(tester, 'Relationship *', 'Park Chairman', index: 1);
      await _fill(tester, 'Phone number *', '08055556666');
      await _fill(tester, 'Address *', 'Ojoo Park, Ibadan', index: 0);
      await _fill(tester, 'Full name *', 'Grace Balogun', index: 1);
      await _fill(tester, 'Relationship *', 'Neighbour', index: 2);
      await _fill(tester, 'Phone number *', '08077778888', index: 1);
      await _fill(tester, 'Address *', 'Aba Opa, Ibadan', index: 1);
  }
}

/// Pumps [path], walks the page so lazily built sections are laid out, and
/// fails if any horizontal RenderFlex overflows at any point.
Future<void> _checkRoute(
  WidgetTester tester,
  int width, {
  String path = '/',
}) async {
  tester.view.physicalSize = Size(width.toDouble(), 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(TeamakApp(initialPath: path));
  await tester.pump(const Duration(milliseconds: 400));

  // The walk runs every frame, not just at the end: some sections overflow
  // only mid-animation (the sticky bar slides in, the promo popup fades in)
  // and are laid out correctly again once they settle.
  final overflows = <String>{};
  for (var i = 0; i < 40; i++) {
    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -400),
    );
    await tester.pump(const Duration(milliseconds: 60));
    overflows.addAll(flexOverflows(tester));
  }

  expect(overflows, isEmpty, reason: '$path at ${width}px: $overflows');
}

void main() {
  // Widths span a small Android phone, the common iPhone sizes, a large phone,
  // a tablet and a desktop, so a regression on any class of screen is caught.
  const widths = <int>[320, 360, 390, 414, 480, 768, 1280];

  for (final width in widths) {
    testWidgets('landing page fits a ${width}px viewport', (tester) async {
      await _checkRoute(tester, width);
    });

    testWidgets('apply wizard fits a ${width}px viewport', (tester) async {
      await _checkRoute(tester, width, path: '/apply');

      // The wizard holds seven steps of different field shapes, so step one
      // alone would not prove the rest fit. Answer each step, advance, and
      // sweep for overflow after every transition.
      for (var step = 0; step < 7; step++) {
        expect(
          flexOverflows(tester),
          isEmpty,
          reason: 'apply step $step at ${width}px',
        );
        if (find.text('Continue').evaluate().isEmpty) break;
        await _completeStep(tester, step);
        await tester.ensureVisible(find.text('Continue'));
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tap(find.text('Continue'));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(
        flexOverflows(tester),
        isEmpty,
        reason: 'apply final step at ${width}px',
      );
    });

    testWidgets('contact page fits a ${width}px viewport', (tester) async {
      await _checkRoute(tester, width, path: '/contact');
    });

    testWidgets('about page fits a ${width}px viewport', (tester) async {
      await _checkRoute(tester, width, path: '/about');
    });

    testWidgets('what we do page fits a ${width}px viewport', (tester) async {
      await _checkRoute(tester, width, path: '/what-we-do');
    });

    testWidgets('team page fits a ${width}px viewport', (tester) async {
      await _checkRoute(tester, width, path: '/team');
    });

    testWidgets('staff login fits a ${width}px viewport', (tester) async {
      await _checkRoute(tester, width, path: '/staff/login');
    });

    testWidgets('404 page fits a ${width}px viewport', (tester) async {
      await _checkRoute(tester, width, path: '/no-such-page');
    });
  }
}

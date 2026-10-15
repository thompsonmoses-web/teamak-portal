import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finder for the `index`-th text field on screen whose `labelText` is [label],
/// or `null` when the current screen has no such field.
///
/// `TextFormField.decoration` cannot be used for this: it is inherited from
/// `FormField<String>` and therefore typed `String?`. The `InputDecoration`
/// is read off the `InputDecorator` the field builds instead.
Finder? fieldWithLabel(String label, {int index = 0}) {
  var seen = 0;
  for (final element in find.byType(TextFormField).evaluate()) {
    final candidate = find.byElementPredicate((e) => identical(e, element));
    final decorator = find.descendant(
      of: candidate,
      matching: find.byType(InputDecorator),
    );
    if (decorator.evaluate().isEmpty) continue;
    final widget = decorator.evaluate().first.widget;
    if (widget is! InputDecorator) continue;
    if (widget.decoration.labelText != label) continue;
    if (seen == index) return candidate;
    seen++;
  }
  return null;
}

/// Types [value] into the labelled field, if the current screen has one.
///
/// Returns whether the field was there: the responsive sweep calls this on
/// every step, and only the steps that ask a question should answer it.
Future<bool> fillField(
  WidgetTester tester,
  String label,
  String value, {
  int index = 0,
}) async {
  final field = fieldWithLabel(label, index: index);
  if (field == null) return false;
  await tester.ensureVisible(field);
  await tester.pump(const Duration(milliseconds: 30));
  await tester.enterText(field, value);
  return true;
}

/// Taps the `index`-th occurrence of [label] when it is on screen.
Future<bool> tapOption(
  WidgetTester tester,
  String label, {
  int index = 0,
}) async {
  final option = find.text(label);
  if (option.evaluate().length <= index) return false;
  final target = option.at(index);
  await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 30));
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 60));
  return true;
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

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

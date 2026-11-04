import 'package:web/web.dart' as web;

/// A tab opened early and steered later: [fill] points it at its
/// destination, [close] discards it when the save never lands.
typedef CarrierTab = ({void Function(String url) fill, void Function() close});

/// Opens a blank tab *now*, while the user's gesture is still fresh.
///
/// Browsers only allow a `window.open` that rides a user activation, and
/// the status save's `await` would otherwise spend it — so the tab is
/// born inside the Confirm tap and merely pointed at its destination
/// once the save lands. A save that never lands closes it instead.
///
/// The handle hands back plain closures rather than the `Window` itself:
/// a JS interop type has no business crossing into code that also runs
/// on the VM.
CarrierTab? openBlankTab() {
  try {
    final tab = web.window.open('about:blank', '_blank');
    if (tab == null) return null;
    return (
      fill: (String url) {
        tab.location.href = url;
      },
      // A closure, not a tear-off: dart2js refuses to turn an interop
      // member into a function value, though calling it is fine.
      close: () {
        tab.close();
      },
    );
  } catch (_) {
    return null;
  }
}

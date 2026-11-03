/// A tab opened early and steered later: [fill] points it at its
/// destination, [close] discards it when the save never lands.
typedef CarrierTab = ({void Function(String url) fill, void Function() close});

/// Opens a blank tab to be filled in later.
///
/// Tests and other non-browser targets have no window to open, so this
/// reports `null` and the caller falls back to its own launch path. The
/// web implementation really opens the tab.
CarrierTab? openBlankTab() => null;

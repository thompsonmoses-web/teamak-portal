import 'package:flutter/material.dart';

import '../theme.dart';

/// Card that lifts and tints toward the brand blue when hovered.
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.accentBar = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool accentBar;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = _hovered
        ? TeamakColors.primary.withValues(alpha: 0.55)
        : const Color(0xFFE4E9F2);

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovered ? -5 : 0, 0),
          padding: widget.padding,
          decoration: BoxDecoration(
            gradient: _hovered
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Colors.white, Color(0xFFF8FAFF)],
                  )
                : null,
            color: _hovered ? null : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border(
              top: BorderSide(
                color: widget.accentBar
                    ? TeamakColors.accent
                    : (_hovered ? TeamakColors.primary : borderColor),
                width: widget.accentBar ? 3.5 : 1.2,
              ),
              left: BorderSide(color: borderColor, width: 1.2),
              right: BorderSide(color: borderColor, width: 1.2),
              bottom: BorderSide(color: borderColor, width: 1.2),
            ),
            boxShadow: _hovered
                ? <BoxShadow>[
                    BoxShadow(
                      color: TeamakColors.primary.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: TeamakColors.accent.withValues(alpha: 0.1),
                      blurRadius: 30,
                      spreadRadius: 1,
                    ),
                  ]
                : <BoxShadow>[
                    BoxShadow(
                      color: TeamakColors.ink.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme.dart';

/// Auto-rotating product showcase for the home screen.
class ShowcaseSlideshow extends StatefulWidget {
  const ShowcaseSlideshow({super.key});

  @override
  State<ShowcaseSlideshow> createState() => _ShowcaseSlideshowState();
}

class _Slide {
  const _Slide(this.image, this.title, this.subtitle, this.tag);

  final String image;
  final String title;
  final String subtitle;
  final String tag;
}

const List<_Slide> _slides = <_Slide>[
  _Slide(
    'assets/slides/motorcycle.png',
    'Bajaj Boxer motorcycles',
    'Own a brand-new commercial bike through Okada Ownership.',
    'OKADA OWNERSHIP',
  ),
  _Slide(
    'assets/slides/tricycle.png',
    'Bajaj tricycles',
    'Approved Maruwa tricycles for commercial riders ready to own.',
    'MARUWA OWNERSHIP',
  ),
  _Slide(
    'assets/slides/solar.png',
    'Sun King solar',
    'Reliable solar home systems for light, phone & TV power.',
    'POWER SOLUTIONS',
  ),
];

class _ShowcaseSlideshowState extends State<ShowcaseSlideshow>
    with TickerProviderStateMixin {
  final PageController _controller = PageController(viewportFraction: 0.94);

  /// Drives the auto-advance countdown shown as the progress bar.
  late final AnimationController _auto = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _auto.addStatusListener((status) {
      if (status == AnimationStatus.completed) _goToNext();
    });
    _auto.forward();
  }

  void _goToNext() {
    if (!mounted || !_controller.hasClients) return;
    final next = (_index + 1) % _slides.length;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  void _goTo(int page) {
    if (!_controller.hasClients) return;
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void _pause() => _auto.stop();

  void _resume() {
    if (_auto.value < 1) _auto.forward();
  }

  @override
  void dispose() {
    _auto.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;

    return Column(
      children: <Widget>[
        SizedBox(
          height: wide ? 340 : 250,
          child: MouseRegion(
            onEnter: (_) => _pause(),
            onExit: (_) => _resume(),
            child: Stack(
              children: <Widget>[
                PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (value) {
                    setState(() => _index = value);
                    _auto.forward(from: 0);
                  },
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _SlideCard(
                      slide: _slides[i],
                      wide: wide,
                    ),
                  ),
                ),
                if (wide) ...<Widget>[
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _ArrowButton(
                        icon: Icons.chevron_left,
                        onTap: () =>
                            _goTo((_index - 1 + _slides.length) % _slides.length),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _ArrowButton(
                        icon: Icons.chevron_right,
                        onTap: () => _goTo((_index + 1) % _slides.length),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Countdown progress bar for the active slide.
        SizedBox(
          height: 4,
          child: AnimatedBuilder(
            animation: _auto,
            builder: (context, _) => Row(
              children: <Widget>[
                for (var i = 0; i < _slides.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            ColoredBox(
                              color:
                                  TeamakColors.primary.withValues(alpha: 0.15),
                            ),
                            if (i == _index)
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _auto.value.clamp(0.0, 1.0),
                                child: const ColoredBox(
                                  color: TeamakColors.accent,
                                ),
                              ),
                            if (i < _index)
                              const ColoredBox(color: TeamakColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (var i = 0; i < _slides.length; i++)
              GestureDetector(
                onTap: () => _goTo(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  width: i == _index ? 28 : 9,
                  height: 9,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: i == _index
                        ? TeamakColors.primary
                        : TeamakColors.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: CircleBorder(
        side: BorderSide(color: TeamakColors.accent.withValues(alpha: 0.8)),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: TeamakColors.primary, size: 26),
        ),
      ),
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({
    required this.slide,
    required this.wide,
  });

  final _Slide slide;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFFFFBF2), Color(0xFFF0F4FF), Color(0xFFFFF8EC)],
            stops: <double>[0, 0.5, 1],
          ),
          border: Border.all(
            color: TeamakColors.accent.withValues(alpha: 0.65),
            width: 1.6,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: TeamakColors.primary.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: TeamakColors.accent.withValues(alpha: 0.18),
              blurRadius: 36,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Fancy soft colour washes.
            Positioned(
              top: -80,
              left: -60,
              child: _GlowCircle(size: 260, color: Color(0x331565C0)),
            ),
            Positioned(
              top: -50,
              right: -30,
              child: _GlowCircle(size: 220, color: Color(0x44F4A81D)),
            ),
            Positioned(
              bottom: -90,
              left: 30,
              child: _GlowCircle(size: 200, color: Color(0x281976D2)),
            ),
            Positioned(
              bottom: -60,
              right: -40,
              child: _GlowCircle(size: 180, color: Color(0x33F4A81D)),
            ),
            // Decorative diagonal gold ribbon.
            Positioned(
              top: -40,
              right: 60,
              child: Transform.rotate(
                angle: 0.55,
                child: Container(
                  width: 90,
                  height: 360,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.transparent,
                        TeamakColors.accent.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Decorative diagonal blue ribbon.
            Positioned(
              bottom: -50,
              left: 80,
              child: Transform.rotate(
                angle: -0.45,
                child: Container(
                  width: 70,
                  height: 300,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.transparent,
                        TeamakColors.primary.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Thin gold accent line across the top inner edge.
            Positioned(
              left: 24,
              right: 24,
              top: 0,
              height: 2.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Colors.transparent,
                      TeamakColors.accent,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Product image area.
            Positioned(
              left: 0,
              right: 0,
              top: wide ? 28 : 16,
              height: wide ? 175 : 120,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 18),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey<String>(slide.image),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
                    ),
                    child: Image.asset(
                      slide.image,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stack) => const Icon(
                        Icons.image_outlined,
                        color: TeamakColors.subtle,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Soft bottom fade for text readability.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: wide ? 120 : 105,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.75),
                      Colors.white.withValues(alpha: 0.92),
                    ],
                    stops: const <double>[0, 0.4, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 22,
              bottom: 14,
              right: 22,
              child: TweenAnimationBuilder<double>(
                key: ValueKey<String>(slide.title),
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - t)),
                    child: child,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                width: 4,
                                height: 13,
                                decoration: BoxDecoration(
                                  color: TeamakColors.accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                slide.tag,
                                style: TextStyle(
                                  color: TeamakColors.primary,
                                  fontSize: wide ? 11 : 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            slide.title,
                            style: TextStyle(
                              color: TeamakColors.ink,
                              fontSize: wide ? 24 : 17,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            slide.subtitle,
                            style: TextStyle(
                              color: TeamakColors.subtle,
                              fontSize: wide ? 13.5 : 12,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (wide) ...<Widget>[
                      const SizedBox(width: 12),
                      const _ExploreButton(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[color, Colors.transparent],
        ),
      ),
    );
  }
}

class _ExploreButton extends StatelessWidget {
  const _ExploreButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[TeamakColors.accent, Color(0xFFE09210)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: TeamakColors.accent.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Explore',
                style: TextStyle(
                  color: TeamakColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 16, color: TeamakColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}

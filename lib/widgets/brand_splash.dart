import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Animated launch screen: civic mark, then the Citizen Desk wordmark.
class BrandSplash extends StatefulWidget {
  const BrandSplash({super.key, this.onFinished});
  final VoidCallback? onFinished;

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  late final Animation<double> _portraitFade = CurvedAnimation(parent: _intro, curve: const Interval(0.0, 0.42, curve: Curves.easeOut));
  late final Animation<double> _portraitScale = Tween(begin: 0.82, end: 1.0).animate(
    CurvedAnimation(parent: _intro, curve: const Interval(0.0, 0.48, curve: Curves.easeOutCubic)),
  );
  late final Animation<double> _titleFade = CurvedAnimation(parent: _intro, curve: const Interval(0.46, 0.74, curve: Curves.easeOut));
  late final Animation<Offset> _titleSlide = Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(
    CurvedAnimation(parent: _intro, curve: const Interval(0.46, 0.74, curve: Curves.easeOutCubic)),
  );
  late final Animation<double> _subFade = CurvedAnimation(parent: _intro, curve: const Interval(0.56, 0.86, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _intro.forward().whenComplete(() {
      if (mounted) _pulse.repeat(reverse: true);
      widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const portrait = 196.0;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Brand.heroBg,
        body: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_intro, _pulse]),
              builder: (context, _) {
                final glow = 0.35 + _pulse.value * 0.25;
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  Opacity(
                    opacity: _portraitFade.value,
                    child: Transform.scale(
                      scale: _portraitScale.value,
                      child: Container(
                        width: portrait,
                        height: portrait,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Brand.red, width: 3),
                          boxShadow: [
                            BoxShadow(color: Brand.gold.withValues(alpha: glow * 0.45), blurRadius: 28, spreadRadius: 2),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Brand.gold, width: 2.5),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2.5),
                              child: ClipOval(
                                child: Image.asset('assets/branding/app_icon.png', fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _titleFade,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: const Text(
                        'Citizen Desk',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Brand.ink, letterSpacing: -0.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeTransition(
                    opacity: _subFade,
                    child: const Text(
                      'Citizen grievance app',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Brand.muted, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: _subFade,
                    child: Container(
                      width: 56,
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: const LinearGradient(colors: [Brand.red, Brand.gold]),
                      ),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

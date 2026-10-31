import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/material.dart';

/// Material 3 window size classes, driven by the space the app actually has
/// (so split-screen, foldables and rotation are handled the same way).
enum WindowSize { compact, medium, expanded }

extension WindowSizeX on BuildContext {
  WindowSize get windowSize {
    final w = MediaQuery.sizeOf(this).width;
    if (w < 600) return WindowSize.compact;
    if (w < 840) return WindowSize.medium;
    return WindowSize.expanded;
  }

  bool get isCompact => windowSize == WindowSize.compact;
}

/// The vertical hinge or fold on dual-screen and foldable devices, if any.
Rect? verticalHinge(BuildContext context) {
  for (final f in MediaQuery.displayFeaturesOf(context)) {
    final isSeparator = f.type == DisplayFeatureType.hinge || f.type == DisplayFeatureType.fold;
    if (isSeparator && f.bounds.height > f.bounds.width) return f.bounds;
  }
  return null;
}

/// Readable content column, centred on wide screens.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.width = 720});
  final Widget child;
  final double width;
  @override
  Widget build(BuildContext context) =>
      Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: width), child: child));
}

/// Shows [primary] alone on compact widths; on wider windows shows [secondary]
/// beside it. On foldables/dual screens the split lands exactly on the hinge so
/// no content sits under it.
class TwoPane extends StatelessWidget {
  const TwoPane({super.key, required this.primary, required this.secondary, this.primaryFraction = 0.42});
  final Widget primary;
  final Widget? secondary;
  final double primaryFraction;

  @override
  Widget build(BuildContext context) {
    if (context.isCompact || secondary == null) return primary;
    return LayoutBuilder(builder: (context, box) {
      final hinge = verticalHinge(context);
      // TwoPane always fills the window to its right edge (beside an optional
      // navigation rail), so its left offset is whatever the window has left over.
      final origin = MediaQuery.sizeOf(context).width - box.maxWidth;
      final left = hinge == null ? 0.0 : hinge.left - origin;
      if (hinge != null && left > 200 && left + hinge.width < box.maxWidth - 200) {
        return Row(children: [
          SizedBox(width: left, child: primary),
          SizedBox(width: hinge.width),
          Expanded(child: secondary!),
        ]);
      }
      return Row(children: [
        SizedBox(width: (box.maxWidth * primaryFraction).clamp(320.0, 460.0), child: primary),
        const VerticalDivider(width: 1),
        Expanded(child: secondary!),
      ]);
    });
  }
}

/// Grid that picks a column count from the available width.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.minItemWidth = 280, this.spacing = 12});
  final List<Widget> children;
  final double minItemWidth, spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cols = (box.maxWidth / minItemWidth).floor().clamp(1, 4);
        final w = (box.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final c in children) SizedBox(width: w, child: c)],
        );
      });
}

class NavDest {
  const NavDest(this.icon, this.selectedIcon, this.label);
  final IconData icon, selectedIcon;
  final String label;
}

/// Bottom navigation bar on phones, navigation rail on tablets / unfolded
/// foldables / landscape, extended rail on large screens.
class AdaptiveNavScaffold extends StatelessWidget {
  const AdaptiveNavScaffold({
    super.key,
    required this.destinations,
    required this.index,
    required this.onSelect,
    required this.body,
    this.railHeader,
  });

  final List<NavDest> destinations;
  final int index;
  final ValueChanged<int> onSelect;
  final Widget body;
  final Widget? railHeader;

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;
    if (size == WindowSize.compact) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: onSelect,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final d in destinations)
              NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
          ],
        ),
      );
    }
    return Scaffold(
      body: Row(children: [
        SafeArea(
          right: false,
          child: NavigationRail(
            selectedIndex: index,
            onDestinationSelected: onSelect,
            extended: size == WindowSize.expanded && MediaQuery.sizeOf(context).width >= 1100,
            labelType: size == WindowSize.expanded && MediaQuery.sizeOf(context).width >= 1100
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: railHeader,
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: body),
      ]),
    );
  }
}

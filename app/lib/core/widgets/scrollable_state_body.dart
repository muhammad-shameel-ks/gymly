/// Centred, scroll-safe body for empty/error/guidance states.
///
/// States are centred while their content fits the parent. When the parent is
/// shorter than the content — a shortened viewport, a large text scale, or a
/// bounded slot such as Home's feed area — the content scrolls instead of
/// overflowing and clipping its CTA (DESIGN.md §4: guided states must stay
/// fully visible, safe area respected).
///
/// The parent MUST bound the height (`Expanded`, a Scaffold body or an
/// equivalent): [LayoutBuilder] needs a finite max height to centre against.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class ScrollableStateBody extends StatelessWidget {
  const ScrollableStateBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.alignment = Alignment.center,
  });

  /// The state content, typically a `Column(mainAxisSize: MainAxisSize.min)`
  /// laid out icon → title → body → CTA.
  final Widget child;

  /// Padding around [child], inside the scrollable area so it is never
  /// pushed past the fold.
  final EdgeInsets padding;

  /// Where [child] sits while it fits; it scrolls once it does not.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        // Clamping (not bounce): the state is not an overscroll surface.
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          // Never shorter than the viewport, so `alignment` centres the state
          // while it fits and the scroll view takes over when it does not.
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Align(
            alignment: alignment,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

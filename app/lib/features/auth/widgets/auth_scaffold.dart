/// Shared chrome for the auth screens.
///
/// Theme background, safe area, 24px screen padding and a keyboard-safe
/// scrollable body: the content stays vertically centred while it fits, and
/// scrolls (keeping the CTA reachable inside the lower two-thirds / thumb
/// zone) once the keyboard shrinks the viewport.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child});

  /// The screen content — the hero/fields/CTA `Column`, each section wrapped in
  /// the motion layer's `StaggeredEntrance` so the visit plays one entrance.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.fromLTRB(
      AppSpace.lg,
      AppSpace.lg,
      AppSpace.lg,
      AppSpace.md,
    );
    return Scaffold(
      backgroundColor: context.palette.bg,
      // Keyboard shrinks the body; the scroll view below keeps the form and
      // CTA in reach.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // Clamped: a keyboard-shrunk viewport must not yield a
                // negative minHeight.
                minHeight: math.max(
                  0.0,
                  constraints.maxHeight - padding.top - padding.bottom,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [child],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

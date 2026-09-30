/// One modal-sheet chrome for the whole app: [showAppSheet] + [AppSheet].
///
/// **Root navigator, always.** Every sheet is pushed with
/// `useRootNavigator: true`, so the sheet is the top-most route of the app's
/// root [Navigator] and not of the current tab's branch navigator. That single
/// route choice is what gives the app one full-screen scrim, one dismiss path
/// and one drag handle:
///
/// - the scrim (barrier) covers the whole app — the bottom `NavigationBar`, a
///   FAB and every other branch are behind it and unreachable, so no second
///   entry point can be tapped while a sheet is up (the old branch-navigator
///   sheet was rendered inside `Scaffold.body`: clipped to the tab, with a
///   barrier that stopped at the `NavigationBar`);
/// - the sheet is a real [ModalRoute] on the root navigator, and that is where
///   the platform back event lands: go_router's delegate stops descending into
///   the shell branches as soon as a page-less route sits above the shell route
///   and asks the root navigator to `maybePop()`, which pops the sheet — so
///   Android back and predictive back dismiss the sheet, never the location;
/// - the drag handle and the barrier dismiss the same route ([Navigator.pop]),
///   so drag-down and tap-outside both return the sheet's value to the caller.
///
/// Sheets are one chrome, never per-screen padding: [AppSheet] owns the
/// surface, the top radius, the grabber pill's clear space, the keyboard inset
/// and the safe area (DESIGN.md §4, “Sheets”). A screen supplies fields, copy,
/// states and its CTA — and fires [Haptics.sheet] at the call site, because one
/// gesture gets one haptic (`core/motion/PROTOCOL.md`).
///
/// Timing is a token, not a controller: [showAppSheet] sets the sheet's
/// durations from `MotionSpec.sheet` (collapsed to `MotionSpec.crossFade` under
/// Reduce Motion) through the framework's `sheetAnimationStyle`, and the
/// **route keeps its own animation controller**. A controller made by the
/// caller is animated by the `vsync` it was created with — and a sheet opened
/// from a tab resolves `Navigator.of(context)` to that tab's *branch*
/// navigator, while the sheet itself is pushed on the *root* one, so the pop
/// never ticks and the sheet can be neither tapped away, dragged down nor
/// back-dismissed. Never hand a sheet a foreign controller.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';

/// Shows an app modal sheet on the **root** navigator.
///
/// The one entry point every sheet goes through: the surface colour, top
/// radius and grabber pill come from `AppTheme.bottomSheetTheme`, the scrim is
/// derived from [AppPalette] (never the framework's `black54`), and the route
/// is always scroll-controlled so the keyboard inset never squashes a form.
/// The body is an [AppSheet].
///
/// [builder] may be called more than once, and its context is under the root
/// navigator — `Navigator.of(context)` inside it resolves to the sheet's own
/// route, so `pop()` closes the sheet. Returns the value passed to
/// [Navigator.pop], or null when the sheet was dismissed by the barrier, by a
/// drag down or by the back gesture.
///
/// [isDismissible] keeps barrier-tap dismissal, [enableDrag] keeps drag-down
/// (both default on; a blocking sheet turns them off). [isScrollControlled]
/// defaults to on and every call site leaves it there — [AppSheet]'s keyboard
/// handling assumes a full-height sheet. [reduceMotion] collapses the sheet's
/// travel to the cross-fade budget; pass `AppMotionConfig.reduceMotionOf(context)`.
///
/// Fires no haptic: the control that was pressed fires `Haptics.sheet()` (one
/// haptic per gesture), and the caller keeps its own `await` /
/// `if (!context.mounted) return;` handling of the result.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool isScrollControlled = true,
  bool reduceMotion = false,
}) {
  final palette = context.palette;
  return showModalBottomSheet<T>(
    context: context,
    // The fix, not a detail: a branch-navigator sheet is not the app's
    // top-most route — it renders inside the tab body, clipped, with a barrier
    // that stops at the NavigationBar.
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    // One grabber pill above every sheet; styled by
    // `AppTheme.bottomSheetTheme` (32×5, `border` — one neutral pill).
    showDragHandle: true,
    // Keeps the sheet clear of the status bar; the bottom edge stays the
    // content's business, which is [AppSheet]'s job.
    useSafeArea: true,
    // Durations only: the framework builds the controller on this route's own
    // navigator, so push, drag and pop all tick (see the library doc — a
    // caller-made controller animated by another navigator's ticker leaves the
    // sheet unable to close).
    sheetAnimationStyle: AnimationStyle(
      duration: reduceMotion ? MotionSpec.crossFade.duration : MotionSpec.sheet.duration,
      reverseDuration:
          reduceMotion ? MotionSpec.crossFade.reverse : MotionSpec.sheet.reverse,
    ),
    // Palette-derived scrim: the dark `bg` dims a dark app, the light
    // `secondary` dims a light one. Never a hardcoded black.
    barrierColor: (palette.isDark ? palette.bg : palette.secondary)
        .withValues(alpha: palette.isDark ? 0.72 : 0.45),
    builder: builder,
  );
}

/// The body chrome of every sheet: surface, top radius, safe-area + keyboard
/// insets, standard padding, optional title, and the scrolling body.
///
/// Layout, outer to inner:
///
/// 1. `Material` — `AppPalette.surface` with the `AppRadius.sheet` top radius
///    and `Clip.antiAlias`, so a scrolling body stays inside the corners (the
///    framework's `bottomSheetTheme` shape is not clipped by default).
/// 2. `Padding` — `AppSpace.screen` horizontally, `AppSpace.md` on top, and at
///    the bottom `max(viewInsets, safe area) + AppSpace.md`: **one** pad for
///    the keyboard and the home indicator, applied in one place. Whichever of
///    the two a surrounding route has already consumed reads as 0 here, so a
///    sheet opened inside another sheet's inset never pads the same space
///    twice.
/// 3. a `Column(mainAxisSize: min)` — the header (see [title]) then a
///    `Flexible` body: `SingleChildScrollView` when [scrollable], the body
///    itself otherwise. Either way the body is bounded by what the keyboard
///    leaves, so a tall form scrolls and the CTA is never covered.
///
/// Mount it only as a `showAppSheet` body: the layout depends on the sheet
/// route's bounded height (the body is sized against it).
///
/// The header sits **outside** the scrollable on purpose: the framework
/// reserves a full-width 48 dp strip above the body for the grabber pill, and
/// the sheet's drag target has to stay reachable while the body scrolls — a
/// drag that starts on the pill or the title drags the sheet down, a drag that
/// starts in the body scrolls it.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    this.title,
    this.subtitle,
    this.scrollable = true,
    required this.child,
  });

  /// Sheet title — `AppType.subtitle` in `palette.text`. Null for a chrome-only
  /// body (a list, a confirmation).
  final String? title;

  /// Optional line under [title] — `AppType.body` in `palette.secondary`
  /// (a phone number, what happens next).
  final String? subtitle;

  /// Whether the chrome wraps [child] in its scroll view. Keep the default for
  /// forms (the body scrolls inside the keyboard insets); pass false only when
  /// the body owns its scrolling (a `Stack` overlay, a list with its own
  /// controller).
  final bool scrollable;

  /// The sheet body: fields, states and the CTA. Already inset and padded.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final media = MediaQuery.of(context);
    // One bottom pad, applied once: the keyboard while it is up, the system
    // safe area otherwise. Either channel reads as 0 when an enclosing route
    // has already consumed it, so nothing is padded twice.
    final bottom = math.max(media.viewInsets.bottom, media.padding.bottom);

    return Material(
      color: palette.surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.screen,
          AppSpace.md,
          AppSpace.screen,
          bottom + AppSpace.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              RiseIn(child: _AppSheetHeader(title: title!, subtitle: subtitle)),
              const SizedBox(height: AppSpace.md),
            ],
            // The body gets exactly the space the chrome leaves — never more.
            // With [scrollable] the chrome scrolls it; without it the body owns
            // its own scrolling (a `Stack` overlay, a controller-driven list)
            // and is still bounded by the chrome, so nothing overflows.
            Flexible(
              child: scrollable ? SingleChildScrollView(child: child) : child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Title + optional subtitle, rising in once with the sheet.
class _AppSheetHeader extends StatelessWidget {
  const _AppSheetHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sub = subtitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppType.subtitle.copyWith(color: palette.text)),
        if (sub != null) ...[
          const SizedBox(height: AppSpace.xs),
          Text(sub, style: AppType.body.copyWith(color: palette.secondary)),
        ],
      ],
    );
  }
}

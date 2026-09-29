/// Due cues for the members slice: the signature ring + the compact dot.
///
/// The row and header cue is [MemberAvatar] — the app's signature
/// [DueRing] around the member's initials, empty the day a member renews and
/// full on the expiry date, so "who is running out" is legible at a glance.
/// [DueDot] stays for far-field feeds that carry no ring.
///
/// Cue *fills* are mode-independent: [dueColor] returns the dark palette's
/// status values in both modes, so a far-field dot keeps the same weight on
/// either surface (DESIGN.md §4: no hex outside `AppPalette`). Anything drawn
/// beside the signature ring uses [dueTextColor] — the ambient palette's
/// status colour, exactly the one [DueRing] sweeps.
library;

import 'package:flutter/material.dart';

import '../../../core/signature/signature.dart';
import '../../../core/theme/app_palette.dart';
import '../models/member.dart';

/// Mode-independent cue fill for a bucket.
Color dueColor(DueBucket bucket) => switch (bucket) {
      DueBucket.overdue => AppPalette.dark.error,
      DueBucket.dueSoon => AppPalette.dark.warning,
      DueBucket.active => AppPalette.dark.success,
    };

/// Status colour for a bucket on the ambient palette: labels, dots, borders.
///
/// [DueRing] sweeps these same values, so one bucket reads as one colour on a
/// screen; use it for anything that sits beside the ring.
Color dueTextColor(AppPalette palette, DueBucket bucket) =>
    switch (bucket) {
      DueBucket.overdue => palette.error,
      DueBucket.dueSoon => palette.warning,
      DueBucket.active => palette.success,
    };

/// Small filled dot for compact dues display.
class DueDot extends StatelessWidget {
  const DueDot({super.key, required this.bucket, this.size = 10});

  final DueBucket bucket;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dueColor(bucket),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// The member's initials inside the signature due ring.
///
/// The ring encodes the elapsed fraction of the member's current subscription
/// period ([periodProgress]); with no subscription it paints full and muted
/// and claims no bucket. [size] is the ring's outer diameter — give it the
/// avatar's diameter plus twice [strokeWidth].
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.entry,
    this.size = 54,
    this.strokeWidth = 3,
  });

  final MemberWithDues entry;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final diameter = size - strokeWidth * 2;
    return DueRing(
      progress: periodProgress(entry.current),
      bucket: entry.bucket,
      size: size,
      strokeWidth: strokeWidth,
      child: SizedBox.square(
        dimension: diameter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.palette.surface,
          ),
          child: Center(
            child: Text(
              _initials(entry.member.name),
              style: TextStyle(
                color: context.palette.text,
                fontSize: diameter * 0.34,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Up to two uppercase initials from [name]; `?` for a blank name.
String _initials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed
      .split(RegExp(r'\s+'))
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();
}

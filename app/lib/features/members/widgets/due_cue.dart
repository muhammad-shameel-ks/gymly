/// Due cues for the members slice: the signature ring + the compact dot.
///
/// The row and header cue is [MemberAvatar] — the app's signature [DueRing]
/// around the member's initials. The ring fills with the paid share of the
/// running tab (`MemberTab.ringFill`, i.e. money paid against the plan he is on)
/// and takes its colour from the due bucket, so "who is behind" is legible at a
/// glance. [DueDot] stays for far-field feeds that carry no ring.
///
/// The wording lives in `money_text.dart` and is re-exported here:
/// [moneyLine] (`₹2,000 pending · due 12 Oct` / `₹500 advance · due 12 Oct`),
/// [rupees] and [shortDate] — Home's card and the member list read the same.
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
import '../../../core/theme/app_tokens.dart';
import '../models/member.dart';

export 'money_text.dart';

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
/// The ring fills with the paid share of the running tab ([MemberTab.ringFill]);
/// when nothing is owed there is nothing to encode, so it paints full and
/// muted and claims no bucket. [size] is the ring's outer diameter — give it
/// the avatar's diameter plus twice [strokeWidth].
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
    final tab = entry.tab;
    return DueRing(
      progress: tab.owed == 0 ? null : tab.ringFill,
      bucket: tab.bucket,
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

/// The `Cancelled` badge a member's row and record carry once he has stopped.
///
/// A quiet pill — the state is a fact, not an alarm, so it wears the neutral
/// border/secondary tokens rather than the error colour.
class MemberCancelledBadge extends StatelessWidget {
  const MemberCancelledBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 2),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        'Cancelled',
        style: AppType.caption.copyWith(color: palette.secondary),
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

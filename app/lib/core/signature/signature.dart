/// `core/signature` — Gymly's one held visual signature.
///
/// One import:
///
/// ```dart
/// import 'package:gymly/core/signature/signature.dart';
/// ```
///
/// [DueRing] encodes money paid against the plan he is on: empty = nothing
/// received, full = his payments cover the tab. Use it on every surface that
/// answers "who is behind" — Member rows, the Member detail header, dues cards.
/// Pass `MemberTab.ringFill` for the fraction, and use [BucketRingPainter] only
/// if you are painting the motif yourself.
///
/// Not for decoration: a surface with nothing owed to show does not get a
/// ring (pass a null `progress` so it paints muted). The full rules live in
/// `due_ring.dart`, the copy voice in `docs/voice.md`.
library;

export 'due_ring.dart';
export 'gymly_mark.dart';

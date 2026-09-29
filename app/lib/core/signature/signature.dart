/// `core/signature` — Gymly's one held visual signature.
///
/// One import:
///
/// ```dart
/// import 'package:gymly/core/signature/signature.dart';
/// ```
///
/// [DueRing] encodes elapsed subscription period: empty = just renewed, full =
/// due. Use it on every surface that answers "who is running out" — Member
/// rows, the Member detail header, dues cards. Use [periodProgress] for the
/// fraction, and [BucketRingPainter] only if you are painting the motif
/// yourself.
///
/// Not for decoration: a surface with no subscription period to show does not
/// get a ring. The full rules live in `due_ring.dart`, the copy voice in
/// `docs/voice.md`.
library;

export 'due_ring.dart';

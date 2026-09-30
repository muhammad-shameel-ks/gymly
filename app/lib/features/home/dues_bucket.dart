/// Home dues-feed shaping: triage ordering + section splitting.
///
/// Bucketing itself is money-derived and lives in the members slice: a
/// member's bucket comes from `computeTab` (`members/domain/member_money.dart`)
/// and reaches the feed as `DuesEntry.bucket`. This file only orders that feed
/// and splits it into the three triage sections — **Overdue → Due soon →
/// Active**.
///
/// Inside a bucket a row orders by its deadline — the missed one for an overdue
/// member, else the next one — with the member's name as the final tie-break.
/// An entry with no deadline in play sorts ahead of the dated ones: nothing is
/// scheduled, so it cannot be waited out.
///
/// Generic over the row type so the plain `DuesEntry` feed and any other
/// dues-shaped row share one ordering. Pure Dart (flutter_test only): no
/// Flutter, no Supabase.
library;

import '../members/models/member.dart';

/// Section order on the feed, most urgent first.
int _rank(DueBucket bucket) => switch (bucket) {
      DueBucket.overdue => 0,
      DueBucket.dueSoon => 1,
      DueBucket.active => 2,
    };

/// No deadline sorts before any deadline (nothing to wait for).
int _compareDeadline(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

/// Feed sorted for triage: bucket rank, then deadline, then member name.
///
/// [deadlineOf] returns the row's governing deadline — the missed one when he
/// is behind, else the next one — or `null` when none is in play.
List<T> sortDuesFeed<T>(
  List<T> entries, {
  required DueBucket Function(T) bucketOf,
  required DateTime? Function(T) deadlineOf,
  required String Function(T) nameOf,
}) {
  final sorted = entries.toList();
  sorted.sort((a, b) {
    final rank = _rank(bucketOf(a)).compareTo(_rank(bucketOf(b)));
    if (rank != 0) return rank;
    final deadline = _compareDeadline(deadlineOf(a), deadlineOf(b));
    if (deadline != 0) return deadline;
    return nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase());
  });
  return sorted;
}

/// Entries of one bucket, preserving feed order.
List<T> bucketEntries<T>(
  List<T> sorted, {
  required DueBucket Function(T) bucketOf,
  required DueBucket bucket,
}) =>
    sorted.where((e) => bucketOf(e) == bucket).toList(growable: false);

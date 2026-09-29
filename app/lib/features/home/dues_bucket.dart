/// Home dues-feed shaping: sort + section helpers.
///
/// Bucketing itself lives in the members slice (`DueBucket.fromExpiry`;
/// a member with no subscription rows resolves to overdue); this file only
/// orders the triage feed: Overdue first, then Due soon, then Active.
/// Within a bucket earliest expiry comes first, and members with no rows
/// surface at the very top — they need attention, not invisibility.
///
/// Generic over the row type so both `MemberWithDues` and the home
/// `DuesEntry` share one ordering; thin `MemberWithDues` conveniences
/// cover the plain case. Pure Dart (flutter_test only).
library;

import '../members/models/member.dart';

int _rank(DueBucket bucket) => switch (bucket) {
      DueBucket.overdue => 0,
      DueBucket.dueSoon => 1,
      DueBucket.active => 2,
    };

/// Null expiry (no subscription rows) sorts before any dated expiry.
int _compareExpiry(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

/// Feed sorted for triage: bucket rank, then expiry, then member name.
List<T> sortDuesFeed<T>(
  List<T> entries, {
  required DueBucket Function(T) bucketOf,
  required DateTime? Function(T) expiryOf,
  required String Function(T) nameOf,
}) {
  final sorted = entries.toList();
  sorted.sort((a, b) {
    final rank = _rank(bucketOf(a)).compareTo(_rank(bucketOf(b)));
    if (rank != 0) return rank;
    final exp = _compareExpiry(expiryOf(a), expiryOf(b));
    if (exp != 0) return exp;
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

/// Sort convenience for plain member rows.
List<MemberWithDues> sortMemberDuesFeed(List<MemberWithDues> entries) =>
    sortDuesFeed(
      entries,
      bucketOf: (e) => e.bucket,
      expiryOf: (e) => e.current?.expiryDate,
      nameOf: (e) => e.member.name,
    );

/// Bucket convenience for plain member rows.
List<MemberWithDues> memberBucketEntries(
  List<MemberWithDues> sorted,
  DueBucket bucket,
) =>
    bucketEntries(sorted, bucketOf: (e) => e.bucket, bucket: bucket);

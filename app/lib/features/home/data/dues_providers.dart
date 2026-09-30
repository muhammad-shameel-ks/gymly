/// Riverpod providers for the Home dues feed.
///
/// Only `flutter_riverpod` + `supabase_flutter` imports plus the gyms
/// (selected gym) and members (models) slices — no foundation imports yet.
/// Feed key: selected gym id (`null` = All gyms).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../gyms/data/selected_gym.dart';
import '../../gyms/providers/gyms_providers.dart' show gymsListProvider;
import '../../members/models/member.dart';
import '../dues_bucket.dart';
import 'dues_repository.dart';
export 'dues_repository.dart';

/// Raw Supabase client. Foundation can override this with a shared provider.
final duesClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
  name: 'homeDuesClient',
);

final duesRepositoryProvider = Provider<DuesRepository>(
  (ref) => DuesRepository(ref.watch(duesClientProvider)),
  name: 'duesRepository',
);

/// Gym ids in scope: the selected gym, or every owned gym when null.
///
/// Resolves to `[]` (never hangs) when a gym is selected-single, when no
/// gyms exist, or while logged out — the gyms list is a plain future.
final duesScopeProvider = FutureProvider<List<String>>((ref) async {
  final selected = ref.watch(selectedGymIdProvider);
  if (selected != null) return <String>[selected];
  final gyms = await ref.watch(gymsListProvider.future);
  if (gyms.isEmpty) return const <String>[];
  return [for (final g in gyms) g.id];
}, name: 'duesScope');

/// Dues feed: members with money outstanding or a deadline in play, sorted
/// Overdue → Due soon → Active, earliest deadline first inside each bucket.
final duesFeedProvider = FutureProvider<List<DuesEntry>>((ref) async {
  final gymIds = await ref.watch(duesScopeProvider.future);
  if (gymIds.isEmpty) return const [];
  final entries =
      await ref.watch(duesRepositoryProvider).watchDues(gymIds: gymIds);
  return sortDuesFeed(
    entries,
    bucketOf: (e) => e.bucket,
    // Inside a bucket a row orders by its deadline: the missed one for an
    // overdue member, else the next one.
    deadlineOf: (e) => e.missedDeadline ?? e.nextDeadline,
    nameOf: (e) => e.member.name,
  );
}, name: 'duesFeed');

/// Feed split into the three triage buckets, preserving feed order.
final duesSectionsProvider = Provider<AsyncValue<List<DuesSection>>>((ref) {
  return ref.watch(duesFeedProvider).whenData(
        (feed) => [
          for (final bucket in DueBucket.values)
            DuesSection(
              bucket: bucket,
              entries: bucketEntries(
                feed,
                bucketOf: (e) => e.bucket,
                bucket: bucket,
              ),
            ),
        ],
      );
}, name: 'duesSections');

/// One triage bucket with its ordered entries.
class DuesSection {
  const DuesSection({required this.bucket, required this.entries});

  final DueBucket bucket;
  final List<DuesEntry> entries;
}

/// Invalidate the feed (and scope) after any write.
void invalidateDuesViews(WidgetRef ref) {
  ref.invalidate(duesScopeProvider);
  ref.invalidate(duesFeedProvider);
}

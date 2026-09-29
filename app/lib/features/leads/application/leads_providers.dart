/// Riverpod state for the Leads tab.
///
/// `gymIdProvider` + `plansListProvider` are integration seams: the App
/// shell (Auth/Gyms slice) overrides [selectedGymIdProvider]; the Plans
/// slice overrides [convertPlansProvider]. Defaults keep this feature
/// runnable standalone.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../plans/models/plan.dart' show durationLabel, formatPlanAmount;
import '../data/inquiries_repository.dart';
import '../data/inquiry.dart';

/// Currently selected gym id. Overridden by the app shell.
final selectedGymIdProvider = StateProvider<String?>((ref) => null);

/// Status filter chips: null = all.
final leadFilterProvider = StateProvider<InquiryStatus?>((ref) => null);

final inquiriesRepositoryProvider = Provider<InquiriesRepository>((ref) {
  return InquiriesRepository(Supabase.instance.client);
});

/// Inquiry list for the selected gym, newest first.
///
/// Plain fetch — never a realtime subscription: `public` is absent from the
/// `supabase_realtime` publication, so a stream on `inquiries` never emits
/// and the tab would hang on its skeleton forever. No gym selected → empty
/// list. Writes re-run it via `ref.invalidate(inquiriesProvider)` in
/// [LeadsController].
final inquiriesProvider = FutureProvider<List<Inquiry>>((ref) async {
  final gymId = ref.watch(selectedGymIdProvider);
  if (gymId == null) return const <Inquiry>[];
  return ref.watch(inquiriesRepositoryProvider).listGym(gymId);
});

/// Filtered view for the list.
final filteredInquiriesProvider = Provider<List<Inquiry>>((ref) {
  final filter = ref.watch(leadFilterProvider);
  final list = ref.watch(inquiriesProvider).value ?? const <Inquiry>[];
  if (filter == null) return list;
  return list.where((i) => i.status == filter).toList();
});

/// Grouped counts per status for the filter chips.
final leadCountsProvider = Provider<Map<InquiryStatus, int>>((ref) {
  final list = ref.watch(inquiriesProvider).value ?? const <Inquiry>[];
  final counts = {for (final s in InquiryStatus.values) s: 0};
  for (final i in list) {
    counts[i.status] = (counts[i.status] ?? 0) + 1;
  }
  return counts;
});

/// Minimal plan row for the convert plan-picker. Overridden by Plans slice
/// or wired to Supabase in integration; default reads `plans` directly.
class ConvertPlan {
  const ConvertPlan(
      {required this.id, required this.name, required this.amountDaysLabel});
  final String id;
  final String name;
  final String amountDaysLabel;
}

final convertPlansProvider = FutureProvider<List<ConvertPlan>>((ref) async {
  final gymId = ref.watch(selectedGymIdProvider);
  if (gymId == null) return const [];
  final rows = await Supabase.instance.client
      .from('plans')
      .select('id,name,amount,duration_days')
      .eq('gym_id', gymId)
      .order('amount');
  return (rows as List).map((r) {
    final m = Map<String, dynamic>.from(r as Map);
    return ConvertPlan(
      id: m['id'] as String,
      name: m['name'] as String,
      amountDaysLabel: '${formatPlanAmount(m['amount'] as num)} · '
          '${durationLabel((m['duration_days'] as num).toInt())}',
    );
  }).toList();
});

/// Controller for add / status / convert mutations with error surfacing.
class LeadsController extends StateNotifier<AsyncValue<void>> {
  LeadsController(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<Inquiry?> add(
      {required String name, required String phone, String? note}) async {
    final gymId = _ref.read(selectedGymIdProvider);
    if (gymId == null) {
      state = AsyncValue.error('Pick a gym first', StackTrace.current);
      return null;
    }
    state = const AsyncValue.loading();
    try {
      final inquiry = await _ref
          .read(inquiriesRepositoryProvider)
          .add(gymId: gymId, name: name, phone: phone, note: note);
      _ref.invalidate(inquiriesProvider);
      state = const AsyncValue.data(null);
      return inquiry;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> setStatus(Inquiry inquiry, InquiryStatus status) async {
    state = const AsyncValue.loading();
    try {
      await _ref
          .read(inquiriesRepositoryProvider)
          .setStatus(inquiry.id, status);
      _ref.invalidate(inquiriesProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Returns the new member id, or throws [DuplicateMemberException].
  Future<String?> convert(Inquiry inquiry, {String? planId}) async {
    state = const AsyncValue.loading();
    try {
      final memberId = await _ref
          .read(inquiriesRepositoryProvider)
          .convert(inquiry: inquiry, planId: planId);
      _ref.invalidate(inquiriesProvider);
      state = const AsyncValue.data(null);
      return memberId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final leadsControllerProvider =
    StateNotifierProvider<LeadsController, AsyncValue<void>>(
        (ref) => LeadsController(ref));

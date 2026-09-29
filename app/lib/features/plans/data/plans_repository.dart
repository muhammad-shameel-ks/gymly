/// Supabase data layer for plans.
///
/// Only third-party imports (`supabase_flutter`); no foundation imports yet.
/// Archiving a plan is a hard delete that is refused when subscriptions
/// (`memberships` rows) still reference it — history must survive per
/// ADR-0001. The DB foreign key surfaces Postgres 23503, mapped here to
/// [ReferencedPlanException] so the UI can show a friendly block message
/// instead of a raw error.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/plan.dart';

/// Thrown when archiving a plan that still has subscriptions referencing it
/// (Postgres foreign-key violation 23503).
///
/// Carries the [plan] and the number of referencing [subscriptionCount]
/// subscriptions (when known) so the UI can explain *why* the archive is
/// blocked — [usageLabel] is the one-line reason in the owner's words, and the
/// form sheet renders it as a warning (caution, never an error).
class ReferencedPlanException implements Exception {
  const ReferencedPlanException(this.plan, {this.subscriptionCount});

  final Plan plan;
  final int? subscriptionCount;

  /// Why the archive is blocked, in the owner's words:
  /// `1 subscription still uses this plan`, `3 subscriptions still use this
  /// plan`, or `This plan still has subscriptions` when the count is unknown.
  String get usageLabel {
    final count = subscriptionCount;
    if (count == null) return 'This plan still has subscriptions';
    return count == 1
        ? '1 subscription still uses this plan'
        : '$count subscriptions still use this plan';
  }

  @override
  String toString() => "$usageLabel, so it can't be archived.";
}

/// CRUD for plans scoped to one gym.
class PlansRepository {
  const PlansRepository(this._client);

  final SupabaseClient _client;

  static const _cols = 'id,gym_id,name,amount,duration_days';

  /// Plans of one gym, cheapest first (stable secondary sort by name).
  Future<List<Plan>> listPlans({required String gymId}) async {
    final rows = await _client
        .from('plans')
        .select(_cols)
        .eq('gym_id', gymId)
        .order('amount', ascending: true)
        .order('name', ascending: true) as List<dynamic>;
    return rows
        .map((r) => Plan.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList(growable: false);
  }

  /// Create a plan. Amount/duration are validated client-side first
  /// (see `plan_validators.dart`); the DB constraints are the backstop.
  Future<Plan> createPlan({
    required String gymId,
    required String name,
    required num amount,
    required int durationDays,
  }) async {
    final row = await _client
        .from('plans')
        .insert({
          'gym_id': gymId,
          'name': name.trim(),
          'amount': amount,
          'duration_days': durationDays,
        })
        .select(_cols)
        .single();
    return Plan.fromJson(row);
  }

  /// Edit name/amount/duration. Past subscriptions keep their own
  /// snapshot via the `plans` embed at read time, so editing a plan
  /// never rewrites history rows.
  Future<Plan> updatePlan({
    required String id,
    required String name,
    required num amount,
    required int durationDays,
  }) async {
    final row = await _client
        .from('plans')
        .update({
          'name': name.trim(),
          'amount': amount,
          'duration_days': durationDays,
        })
        .eq('id', id)
        .select(_cols)
        .single();
    return Plan.fromJson(row);
  }

  /// Archive a plan (hard delete).
  ///
  /// Throws [ReferencedPlanException] when subscriptions still reference
  /// the plan — the plan is left untouched in that case.
  Future<void> archivePlan(Plan plan) async {
    try {
      await _client.from('plans').delete().eq('id', plan.id);
    } on PostgrestException catch (e) {
      if (isReferenceViolation(e)) {
        int? usage;
        try {
          usage = await _countSubscriptions(planId: plan.id);
        } catch (_) {
          usage = null;
        }
        throw ReferencedPlanException(plan, subscriptionCount: usage);
      }
      rethrow;
    }
  }

  /// How many subscription rows reference [planId] (for block messages).
  Future<int> _countSubscriptions({required String planId}) async {
    final rows = await _client
        .from('memberships')
        .select('id')
        .eq('plan_id', planId)
        .limit(1000) as List<dynamic>;
    return rows.length;
  }

  /// True for Postgres foreign-key violations (23503): a
  /// `memberships.plan_id` row still points at the plan.
  static bool isReferenceViolation(PostgrestException e) =>
      e.code == '23503' ||
      e.message.contains('foreign key') ||
      e.message.contains('memberships');
}

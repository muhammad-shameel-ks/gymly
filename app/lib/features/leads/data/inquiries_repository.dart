/// Supabase data layer for inquiries (`inquiries` table).
///
/// RLS is owner-via-gym; all queries scope by `gym_id`.
/// Convert flow: create member (+ optional first stretch from a plan) then
/// mark the inquiry `joined` linking `member_id`.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../members/data/members_repository.dart' show MembersRepository;
import 'inquiry.dart';
import 'lead_validators.dart';

/// Thrown when a convert finds an existing member with the same phone
/// (UNIQUE(gym_id, phone)). Caller should open the existing member.
class DuplicateMemberException implements Exception {
  const DuplicateMemberException(this.memberId);
  final String memberId;
}

class InquiriesRepository {
  InquiriesRepository(this._client);

  final SupabaseClient _client;

  /// All inquiries of one gym, newest first.
  ///
  /// Plain fetch, not a realtime stream: `public` has no tables in the
  /// `supabase_realtime` publication, so streams never emit. Callers
  /// re-run this after a write via `ref.invalidate(inquiriesProvider)`.
  Future<List<Inquiry>> listGym(String gymId) async {
    final rows = await _client
        .from('inquiries')
        .select()
        .eq('gym_id', gymId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Inquiry.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<Inquiry> add({
    required String gymId,
    required String name,
    required String phone,
    String? note,
  }) async {
    final row = await _client.from('inquiries').insert({
      'gym_id': gymId,
      'name': name.trim(),
      'phone': normalizePhone(phone),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'status': InquiryStatus.fresh.value,
    }).select().single();
    return Inquiry.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Inquiry> setStatus(String inquiryId, InquiryStatus status,
      {String? memberId}) async {
    final patch = <String, dynamic>{'status': status.value};
    if (memberId != null) patch['member_id'] = memberId;
    final row = await _client
        .from('inquiries')
        .update(patch)
        .eq('id', inquiryId)
        .select()
        .single();
    return Inquiry.fromJson(Map<String, dynamic>.from(row));
  }

  /// Convert an inquiry to a member.
  ///
  /// 1. Insert into `members` (name/phone/note from inquiry).
  ///    On unique-violation (duplicate phone in gym) throws
  ///    [DuplicateMemberException] with the existing member id.
  /// 2. Optionally start a first stretch from [planId] today, with an optional
  ///    [priceOverride] and the amount received now ([firstPayment]), through
  ///    the members repository so convert and the member form share one path.
  /// 3. Mark inquiry `joined` with `member_id`.
  Future<String> convert({
    required Inquiry inquiry,
    String? planId,
    int? priceOverride,
    int? firstPayment,
  }) async {
    String memberId;
    try {
      final member = await _client.from('members').insert({
        'gym_id': inquiry.gymId,
        'name': inquiry.name,
        'phone': inquiry.phone,
        if (inquiry.note != null && inquiry.note!.isNotEmpty)
          'note': inquiry.note,
      }).select('id').single();
      memberId = (member as Map)['id'] as String;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        final existing = await _client
            .from('members')
            .select('id')
            .eq('gym_id', inquiry.gymId)
            .eq('phone', inquiry.phone)
            .limit(1);
        final id = (existing as List).isNotEmpty
            ? ((existing.first as Map)['id'] as String)
            : '';
        throw DuplicateMemberException(id);
      }
      rethrow;
    }

    if (planId != null) {
      // Same path as the member form: the plan's price/duration are copied
      // onto the stretch, with an optional price override and the amount
      // received today.
      await MembersRepository(_client).startSubscription(
        gymId: inquiry.gymId,
        memberId: memberId,
        planId: planId,
        startDate: DateTime.now(),
        priceOverride: priceOverride,
        firstPayment: firstPayment,
      );
    }

    await setStatus(inquiry.id, InquiryStatus.joined, memberId: memberId);
    return memberId;
  }
}

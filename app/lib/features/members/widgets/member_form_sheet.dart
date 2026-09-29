/// Create/edit member sheet honoring `UNIQUE(gym_id, phone)`.
///
/// On a 23505 conflict the repository throws [DuplicateMemberException]; this
/// sheet catches it and answers with the non-blaming "already a member" card
/// plus a link to the existing member's detail. Create mode offers a plan
/// picker (from the plans table) to assign the first subscription.
///
/// Content staggers in once per open on the shared [AppSheet] chrome (surface,
/// radius, keyboard inset, title), the primary CTA carries its busy state
/// in-button (no full-screen spinner), and every outcome is haptically
/// confirmed: success on save, error on a refused save or a duplicate phone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_sheet.dart';
import '../data/members_repository.dart';
import '../models/member.dart';
import '../providers/members_providers.dart';
import 'member_detail_screen.dart';

class MemberFormSheet extends ConsumerStatefulWidget {
  const MemberFormSheet({super.key, required this.gymId, this.existing});

  final String gymId;

  /// Null = create mode; non-null = edit mode.
  final Member? existing;

  @override
  ConsumerState<MemberFormSheet> createState() => _MemberFormSheetState();
}

class _MemberFormSheetState extends ConsumerState<MemberFormSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _note;
  String? _planId;
  bool _saving = false;

  /// Conflicting member from a 23505, shown with the "open instead" link.
  Member? _duplicate;

  static final _nonDigits = RegExp(r'\D');

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _nameError(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Enter a name' : null;

  /// Name the fix, never blame the owner (voice rule 6).
  String? _phoneError(String? v) =>
      (v ?? '').replaceAll(_nonDigits, '').length == 10
          ? null
          : 'Enter a 10-digit phone number';

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      Haptics.error();
      return;
    }
    setState(() {
      _saving = true;
      _duplicate = null;
    });
    final repo = ref.read(membersRepositoryProvider);
    try {
      if (_editing) {
        await repo.updateMember(
          id: widget.existing!.id,
          name: _name.text,
          phone: _phone.text,
          note: _note.text,
        );
        invalidateMemberViews(ref,
            gymId: widget.gymId, memberId: widget.existing!.id);
      } else {
        final created = await repo.createMember(
          gymId: widget.gymId,
          name: _name.text,
          phone: _phone.text,
          note: _note.text,
          planId: _planId,
        );
        invalidateMemberViews(ref,
            gymId: widget.gymId, memberId: created.id);
      }
      Haptics.success();
      if (mounted) Navigator.of(context).pop();
    } on DuplicateMemberException catch (e) {
      // Recoverable, not the owner's fault: offer the existing member.
      Haptics.error();
      setState(() => _duplicate = e.existing);
    } catch (_) {
      Haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't save member. Check your connection, then try again.",
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openDuplicate() {
    final dup = _duplicate;
    if (dup == null) return;
    Haptics.impact();
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MemberDetailScreen(gymId: widget.gymId, memberId: dup.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans = _editing
        ? null
        : ref.watch(plansForGymProvider(widget.gymId));
    return AppSheet(
      title: _editing ? 'Edit member' : 'New member',
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaggeredEntrance(
              index: 0,
              child: TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.words,
                validator: _nameError,
              ),
            ),
            const SizedBox(height: 8),
            StaggeredEntrance(
              index: 1,
              child: TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                validator: _phoneError,
              ),
            ),
            const SizedBox(height: 8),
            StaggeredEntrance(
              index: 2,
              child: TextFormField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                ),
                maxLines: 2,
              ),
            ),
            if (!_editing) ...[
              const SizedBox(height: 8),
              StaggeredEntrance(
                index: 3,
                child: plans?.when(
                      loading: () => const Shimmer(
                        child: ShimmerBox(height: 56),
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (ps) => DropdownButtonFormField<String>(
                        initialValue: _planId,
                        decoration: const InputDecoration(
                          labelText: 'Plan (optional)',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No plan yet'),
                          ),
                          for (final p in ps)
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(p.label),
                            ),
                        ],
                        onChanged: (v) {
                          Haptics.select();
                          setState(() => _planId = v);
                        },
                      ),
                    ) ??
                    const SizedBox.shrink(),
              ),
            ],
            if (_duplicate != null) ...[
              const SizedBox(height: 12),
              RiseIn(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.palette.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.palette.warning),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_duplicate!.name} is already a member.',
                          style: TextStyle(
                            color: context.palette.text,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      TapScale(
                        child: TextButton(
                          onPressed: _openDuplicate,
                          child: Text('Open ${_duplicate!.name}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            StaggeredEntrance(
              index: 4,
              child: SizedBox(
                height: 48,
                child: TapScale(
                  enabled: !_saving,
                  enableHaptic: false,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_editing ? 'Save member' : 'Add member'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

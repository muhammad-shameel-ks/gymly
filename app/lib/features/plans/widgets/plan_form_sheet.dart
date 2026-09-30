/// Create/edit plan sheet with validation + guarded archive.
///
/// Validation (client-side, mirrored by DB constraints): name required,
/// `amount >= 0`, `duration_days > 0` (see `plan_validators.dart`).
/// Archive (edit mode only) deletes the plan; when subscriptions still
/// reference it the repository throws [ReferencedPlanException] and this
/// sheet keeps the plan and shows the friendly block message instead.
///
/// Motion: the sheet's body sections (fields → actions) stagger in once per
/// open via [StaggeredEntrance] on the shared [AppSheet] chrome (surface,
/// radius, keyboard inset, title); the blocked-archive warning rises in where
/// it appears ([RiseIn]); both buttons carry the shared press feedback
/// ([TapScale]) and drop translation under Reduce Motion like every primitive.
///
/// Haptics are the outcome of the gesture, one per gesture:
/// [Haptics.success] when a save or archive commits, [Haptics.error] when
/// validation or the database refuses it (a blocked archive is a refusal too —
/// the plan simply has history).
///
/// Colours come from [AppPalette] (`context.palette`): the theme fills form
/// fields and the primary button with the accent/`onAccent` pair, and
/// `warning` marks the archive block — caution, never an error.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../data/plan_validators.dart';
import '../data/plans_repository.dart';
import '../models/plan.dart';
import '../providers/plans_providers.dart';

class PlanFormSheet extends ConsumerStatefulWidget {
  const PlanFormSheet({super.key, required this.gymId, this.existing});

  final String gymId;

  /// Null = create mode; non-null = edit mode.
  final Plan? existing;

  @override
  ConsumerState<PlanFormSheet> createState() => _PlanFormSheetState();
}

class _PlanFormSheetState extends ConsumerState<PlanFormSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _days;
  bool _saving = false;
  bool _archiving = false;

  /// Blocked archive from a [ReferencedPlanException]; rendered as a warning
  /// surface (what happened + what to do), not as an error.
  ReferencedPlanException? _archiveBlock;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _amount = TextEditingController(
      text: e == null
          ? ''
          : (e.amount.remainder(1) == 0
              ? e.amount.toInt().toString()
              : e.amount.toString()),
    );
    _days = TextEditingController(text: e?.durationDays.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _days.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      // Refused: the field errors are the visual pair for this haptic.
      Haptics.error();
      return;
    }
    setState(() {
      _saving = true;
      _archiveBlock = null;
    });
    try {
      final repo = ref.read(plansRepositoryProvider);
      final amount = num.parse(_amount.text.trim());
      final days = int.parse(_days.text.trim());
      if (_editing) {
        await repo.updatePlan(
          id: widget.existing!.id,
          name: _name.text,
          amount: amount,
          durationDays: days,
        );
      } else {
        await repo.createPlan(
          gymId: widget.gymId,
          name: _name.text,
          amount: amount,
          durationDays: days,
        );
      }
      invalidatePlanViews(ref);
      // Committed: past tense + the fact is the closing sheet itself.
      Haptics.success();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      Haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't save plan. Check your connection, then try again.",
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archive() async {
    final plan = widget.existing;
    if (plan == null) return;
    setState(() {
      _archiving = true;
      _archiveBlock = null;
    });
    try {
      await ref.read(plansRepositoryProvider).archivePlan(plan);
      invalidatePlanViews(ref);
      Haptics.success();
      if (mounted) Navigator.of(context).pop();
    } on ReferencedPlanException catch (e) {
      // Refused, not failed: the plan has history, so the sheet warns instead
      // of erroring and the plan stays.
      Haptics.error();
      if (mounted) setState(() => _archiveBlock = e);
    } catch (_) {
      Haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't archive the plan. Check your connection, then try again.",
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textStyle = AppType.body.copyWith(color: palette.text);

    InputDecoration deco(String label, String hint) => InputDecoration(
          labelText: label,
          hintText: hint,
        );

    return AppSheet(
      title: _editing ? 'Edit plan' : 'New plan',
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaggeredEntrance(
              index: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    style: textStyle,
                    textCapitalization: TextCapitalization.words,
                    decoration: deco('Name', 'e.g. 3 months'),
                    validator: (v) {
                      final err = validatePlanForm(
                        name: v ?? '',
                        amount: _amount.text,
                        durationDays: _days.text,
                      );
                      return err.name;
                    },
                  ),
                  const SizedBox(height: AppSpace.gap),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amount,
                          style: textStyle,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: deco('Amount (₹)', 'e.g. 3333'),
                          validator: (v) {
                            final err = validatePlanForm(
                              name: _name.text,
                              amount: v ?? '',
                              durationDays: _days.text,
                            );
                            return err.amount;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpace.gap),
                      Expanded(
                        child: TextFormField(
                          controller: _days,
                          style: textStyle,
                          keyboardType: TextInputType.number,
                          decoration: deco('Duration (days)', 'e.g. 90'),
                          validator: (v) {
                            final err = validatePlanForm(
                              name: _name.text,
                              amount: _amount.text,
                              durationDays: v ?? '',
                            );
                            return err.durationDays;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_archiveBlock != null) ...[
              const SizedBox(height: 12),
              RiseIn(child: _ArchiveBlockWarning(block: _archiveBlock!)),
            ],
            const SizedBox(height: AppSpace.md),
            StaggeredEntrance(
              index: 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 48,
                    child: TapScale(
                      enabled: !_saving,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          disabledBackgroundColor:
                              palette.accent.withValues(alpha: 0.45),
                          disabledForegroundColor:
                              palette.onAccent.withValues(alpha: 0.6),
                          textStyle: AppType.body
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        child: Text(
                          _saving
                              ? 'Saving…'
                              : _editing
                                  ? 'Save plan'
                                  : 'Add plan',
                        ),
                      ),
                    ),
                  ),
                  if (_editing) ...[
                    const SizedBox(height: AppSpace.sm),
                    SizedBox(
                      height: 48,
                      child: TapScale(
                        enabled: !_archiving,
                        child: OutlinedButton.icon(
                          onPressed: _archiving ? null : _archive,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.text,
                          ),
                          icon: const Icon(Icons.archive_outlined),
                          label: Text(
                            _archiving ? 'Archiving…' : 'Archive plan',
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The blocked-archive surface: caution, not an error.
///
/// The plan is fine — it just has history — so the reason comes first
/// ([ReferencedPlanException.usageLabel]) and the next step follows, in the
/// owner's words.
class _ArchiveBlockWarning extends StatelessWidget {
  const _ArchiveBlockWarning({required this.block});

  final ReferencedPlanException block;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 20, color: palette.warning),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  block.usageLabel,
                  style: AppType.body.copyWith(
                    color: palette.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            "It can't be archived. Keep it, so past subscriptions stay on record.",
            style: AppType.body.copyWith(color: palette.secondary),
          ),
        ],
      ),
    );
  }
}

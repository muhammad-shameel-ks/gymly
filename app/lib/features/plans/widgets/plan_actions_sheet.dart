/// Plan action sheet: the moves for one plan, in one place.
///
/// A plan card is a doorway, not an editor, so a card tap lands here instead of
/// dropping the owner straight into the form on a mis-tap. Rows, in order:
///
/// - `Edit plan` — the one deliberate route into [PlanFormSheet] in edit mode,
///   handed in as the screen's existing edit entry point
///   (`_openSheet(context, PlanFormSheet(gymId: …, existing: plan))`), so
///   validation and the guarded archive behave exactly as they did before this
///   sheet existed.
///
/// That is the whole list, and deliberately so: the only lifecycle move the
/// repository supports is `PlansRepository.archivePlan` (a hard delete), and its
/// single mutation path — repository call, `invalidatePlanViews`, success/error
/// haptics and the blocked-archive warning surface for
/// [ReferencedPlanException] — lives inside [PlanFormSheet]. Restating that here
/// would be a second archive surface with its own refusal rendering, so archive
/// stays inside the edit form rather than being duplicated.
///
/// Haptics: one per gesture. The card that opened this sheet already fired its
/// press impact (the sheet arrives silently, like every sheet in this tab), and
/// each row fires [Haptics.select] as it closes, immediately next to the visual
/// change it confirms.
///
/// Colours come from [AppPalette] (`context.palette`), rows are 48 dp with a
/// trailing chevron so the sheet reads exactly like the other action sheets.
library;

import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../models/plan.dart';

/// Opens the actions available on [plan], titled with the plan's name.
///
/// [onEdit] is the screen's own edit entry point; it runs after the sheet has
/// closed, so the form never opens behind a sheet and the host context stays
/// the live one that opened this sheet.
Future<void> showPlanActionsSheet(
  BuildContext context, {
  required Plan plan,
  required VoidCallback onEdit,
}) {
  return showAppSheet<void>(
    context,
    builder: (_) => AppSheet(
      title: plan.name,
      child: _PlanActions(onEdit: onEdit),
    ),
  );
}

/// The sheet's rows.
class _PlanActions extends StatelessWidget {
  const _PlanActions({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActionRow(
          icon: Icons.edit_outlined,
          label: 'Edit plan',
          onPressed: () => _edit(context),
        ),
      ],
    );
  }

  /// One select haptic, the sheet closes, then the existing form opens — the
  /// sheet never stays up behind the next route.
  void _edit(BuildContext context) {
    Haptics.select();
    Navigator.of(context).pop();
    onEdit();
  }
}

/// One full-width 48 dp sheet row: icon + verb, then a trailing chevron — the
/// same row shape as the lead actions sheet, so a sheet row reads identically
/// across features.
///
/// The press response is [TapScale]'s; the haptic belongs to the action behind
/// the row, never to the row chrome.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = context.palette.text;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TapScale(
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            foregroundColor: foreground,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(color: foreground),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: context.palette.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

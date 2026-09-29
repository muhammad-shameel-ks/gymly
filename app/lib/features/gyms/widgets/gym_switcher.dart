import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../providers/gyms_providers.dart';

/// Sentinels for the trailing management rows. Distinct enum values, so they
/// can never equal a gym id — nor `null`, which means All gyms.
enum _SwitcherRow { divider, manageGyms }

/// Menu floor: the pill measures its own label rather than the widest menu
/// row, so the menu needs a minimum of its own to fit the wider
/// 'Manage gyms' row without clipping it.
const double _menuMinWidth = 240;

/// Header gym switcher: dropdown of the Owner's gyms plus an "All gyms"
/// option, then a divider and a "Manage gyms" row that opens `/gyms` (the
/// Owner's only way to create a 2nd, 3rd, nth gym). `null` selection =
/// All gyms (Home aggregates across gyms).
///
/// The menu is a modal surface, so opening it haptics like one
/// ([Haptics.sheet]) and choosing a row is a discrete move ([Haptics.select]);
/// the pill itself takes the shared press scale. Loading shows a shimmering
/// skeleton chip, not a spinner. Colours come from [AppPalette].
class GymSwitcher extends ConsumerWidget {
  const GymSwitcher({super.key});

  /// Opens the gyms-management screen after the dropdown has closed.
  void _openManageGyms(BuildContext context) {
    // The dropdown pops itself before `onChanged` fires; the push is deferred
    // one frame so the menu is gone before the shell swaps pages.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.push('/gyms');
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gyms = ref.watch(gymsListProvider);
    final selected = ref.watch(selectedGymIdProvider);
    final palette = context.palette;

    return gyms.when(
      skipLoadingOnReload: true,
      loading: () => const _SwitcherSkeleton(),
      error: (_, _) => TapScale(
        onTap: null,
        dimOpacity: 0.94,
        child: TextButton(
          onPressed: () {
            // A control was pressed; the shimmer that replaces it is the
            // visible change.
            Haptics.impact();
            ref.invalidate(gymsListProvider);
          },
          child: const Text('Retry gyms'),
        ),
      ),
      data: (list) {
        final validSelection =
            list.any((g) => g.id == selected) ? selected : null;
        // Compact pill: the face measures the selected label (see
        // `selectedItemBuilder`) instead of the widest menu row, so the caret
        // hugs the text. 44dp keeps the tap target; `minHeight` (not a fixed
        // height) lets the pill grow when the text scale does.
        return TapScale(
          // The dropdown owns the tap (it opens the menu); TapScale only adds
          // the press scale, so the menu's own haptics stay the only ones.
          onTap: null,
          dimOpacity: 0.94,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: palette.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Object?>(
                value: validSelection,
                isDense: true,
                hint: _SwitcherLabel('All gyms', color: palette.secondary),
                // The menu is arriving: the haptic that says a surface came up.
                onTap: Haptics.sheet,
                // Only a real selection (All gyms or a gym) can appear on the
                // face; the divider and 'Manage gyms' rows never can.
                selectedItemBuilder: (context) => [
                  _SwitcherLabel('All gyms', color: palette.text),
                  for (final gym in list)
                    _SwitcherLabel(gym.name, color: palette.text),
                  const SizedBox.shrink(),
                  const SizedBox.shrink(),
                ],
                menuWidth: _menuMinWidth,
                dropdownColor: palette.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                iconSize: 18,
                iconEnabledColor: palette.secondary,
                items: [
                  DropdownMenuItem<Object?>(
                    value: null,
                    child: _SwitcherLabel('All gyms', color: palette.text),
                  ),
                  for (final gym in list)
                    DropdownMenuItem<Object?>(
                      value: gym.id,
                      child: _SwitcherLabel(gym.name, color: palette.text),
                    ),
                  // Management rows: a hairline separator then the entry point
                  // to create/rename/delete gyms.
                  const DropdownMenuItem<Object?>(
                    value: _SwitcherRow.divider,
                    enabled: false,
                    child: Divider(height: 1),
                  ),
                  DropdownMenuItem<Object?>(
                    value: _SwitcherRow.manageGyms,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 18,
                          color: palette.secondary,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: _SwitcherLabel(
                            'Manage gyms',
                            color: palette.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  // A menu row was chosen: a discrete value moved.
                  Haptics.select();
                  if (value == _SwitcherRow.manageGyms) {
                    _openManageGyms(context);
                    return;
                  }
                  // Any other selectable row is a gym id, or `null` = All
                  // gyms. The notifier persists the pick and is the only
                  // mutation path.
                  ref
                      .read(selectedGymIdProvider.notifier)
                      .setGym(value as String?);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One switcher label: a single line at [AppType.body], coloured explicitly
/// so the pill and the menu agree.
class _SwitcherLabel extends StatelessWidget {
  const _SwitcherLabel(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppType.body.copyWith(color: color),
    );
  }
}

/// Neutral skeleton chip occupying the switcher's footprint while the gym
/// list loads — no spinner, no layout shift, and the placeholder bars stream
/// through the shared [Shimmer] (the pill keeps its own fill).
class _SwitcherSkeleton extends StatelessWidget {
  const _SwitcherSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 44,
      width: 140,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.border),
      ),
      child: const Shimmer(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShimmerBox(width: 76, height: 12),
            SizedBox(width: AppSpace.sm),
            ShimmerBox(width: 10, height: 10, radius: 3),
          ],
        ),
      ),
    );
  }
}

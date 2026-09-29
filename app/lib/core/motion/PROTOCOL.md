# Motion protocol (core/motion)

Motion communicates **state and relationships**. It never decorates. One import:

```dart
import 'package:gymly/core/motion/motion.dart';
```

## Budgets

| Interaction | Spec | Budget | Scheme |
|---|---|---|---|
| Tap confirm (press/release) | `MotionSpec.tap` / `.tapRelease` | 100–150 ms, scale ~0.97 | spring |
| Toggle / chip / switch | `MotionSpec.toggle` | 150–200 ms | spring |
| Cards/rows appear | `MotionSpec.appear` | 200–300 ms, stagger 40 ms | spring |
| Screen push / pop | `MotionSpec.push` | 325 ms / 300 ms | M3 curve |
| Bottom-tab switch (shared axis X) | `MotionSpec.appear` | 250 ms, slide ~8% + fade | M3 curve |
| Sheet up / down | `MotionSpec.sheet` | 425 ms / 240 ms | spring |
| Selection / status pop | `MotionSpec.pop` | 200 ms, one overshoot | spring |
| Bounded fill / reset (ring, arc) | `MotionSpec.fill` | 300 ms / 175 ms | spring |
| Count-up | `MotionSpec.count` | 280 ms | spring |
| Reduce Motion cross-fade | `MotionSpec.crossFade` | 160 ms, opacity only | — |

Drive through the spec, never hand-rolled timing: `MotionSpec.appear.drive(ctrl, target: 1, scheme: AppMotionConfig.of(context).scheme)`.

## Reduce Motion

`AppMotionConfig.of(context).reduceMotion` (or `context.motion`): nearest
`AppMotionConfig`, else `MediaQuery.disableAnimationsOf`. Read it in
`didChangeDependencies` — never `initState` — store it in a field, and **drop
translation/scale, keep opacity**. Haptics are not motion; they stay on.

## Do / Don't

- **Do** animate `transform`/`opacity` only. **Don't** touch width/height/top/left/margin.
- **Do** use springs for gesture-linked motion. **Don't** tween where the finger sets the pace.
- **Do** build controllers in `initState`, precompute tweens/curves there, dispose them.
  **Never** create a controller, tween or `CurvedAnimation` inside `build`.
- **Never** schedule an entrance with `Future.delayed`; use `StaggeredEntrance`/`RiseIn`.
- **Do** keep one entrance per screen visit. **Don't** replay on rebuild or loop outside a skeleton.
- **Do** animate a tab body **in place** with `TabTransition` — a transform/opacity
  wrapper around the live `StatefulNavigationShell`. **Never** remount it: the shell owns
  one `Navigator` per branch behind `GlobalKey`s, so an `AnimatedSwitcher`/`PageView`/
  `KeyedSubtree` with a changing key mounts a second copy (duplicate global keys, or a
  disposed branch navigator) and loses every tab's state. Wrappers only; no child swapping,
  no re-keying.
- **Don't** exceed 400 ms on a small transition; push/pop stays 300–350 ms.
- **Don't** haptic a data change, a scroll tick or a background refresh, and don't add
  motion to a destructive confirm beyond its haptic + the dialog.

## Haptic meanings (one meaning per call)

| Call | Means | Use for |
|---|---|---|
| `Haptics.select()` | discrete value moved | picker, segmented control, chip |
| `Haptics.impact()` (light) | snap / toggle | button press, switch, row tap |
| `Haptics.impact(strength: medium)` | a surface arrived | card expanding in place |
| `Haptics.impact(strength: heavy)` | heavy commitment | destructive confirm accepted |
| `Haptics.success()` | committed | save, renew, convert |
| `Haptics.error()` | refused | validation failure, action aborted |
| `Haptics.sheet()` | modal surface arrived | sheet, dialog, gym switcher |

## Usage

```dart
// Press: with no callbacks it wraps an inner InkWell instead of owning the tap.
TapScale(onTap: renew, child: FilledButton(onPressed: renew, child: Text('Renew')));
PressableCard(onTap: () => open(member), child: MemberRow(member));   // card / row state

// Entrance: index = position; plays once per visit, cross-fades under Reduce Motion.
StaggeredEntrance(index: i, child: DueCard(dues: rows[i]));
RiseIn(child: EmptyState(...));                        // single child, no stagger

// Tab switch: one in-place wrapper around the shell's body; the bar stays put.
// Direction comes from the previous vs the new index — never re-key the shell.
TabTransition(index: shell.currentIndex, child: shell);

// Numbers, skeleton, state change (all visual — the owning control fires haptics).
AnimatedCounter(value: overdueCount, style: body.copyWith(color: p.text));
AnimatedAmount(amount: due.planAmount, style: body.copyWith(color: p.text));
Shimmer(child: Column(children: [ShimmerBox(width: 140), ShimmerBox(height: 48)]));
AnimatedCheck(selected: selected, color: p.onAccent);
AnimatedStatusDot(color: bucketColor, statusKey: bucket);

// Sheet: theme + haptic; own the timing only when you must.
Haptics.sheet(); await showModalBottomSheet(context: context, builder: ...);
```

Custom routes use `AppTransitions.builder`; sheet timing uses
`AppTransitions.sheetController(vsync, reduceMotion: …)`.
`features/auth/widgets/auth_entrance.dart` declares its own public `StaggeredEntrance` — delete it when you adopt the core one.

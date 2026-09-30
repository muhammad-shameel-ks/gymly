/// The updater as one card on the Profile screen: the installed version, and
/// the one action that is possible right now.
///
/// Every state has exactly one control, and it never moves — check → download →
/// install, then `Check for update` again. Copy follows `docs/voice.md`: the
/// caption says what is true, the button says what the tap does, and a failure
/// names what happened and offers `Retry`.
///
/// Motion stays quiet, like the rest of this screen: nothing animates in, and
/// the buttons carry the shared press feedback ([TapScale]). Haptics are the
/// outcome of the gesture, one per gesture: [Haptics.impact] on the tap,
/// [Haptics.impact] at medium strength when an offer arrives (a surface that
/// arrived), [Haptics.success] when the download commits, [Haptics.error] when
/// the check, the download or the installer refuses.
///
/// A failed *action* (download, installer) rides a snackbar and leaves the card
/// on the state the owner can act on; a failed *check* is a state of its own,
/// because the card is then the only report.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../providers/updater_providers.dart';

/// Version + check + download + install, as one card.
class UpdateCard extends ConsumerWidget {
  const UpdateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final version = ref.watch(installedVersionProvider).value;
    final state = ref.watch(updaterProvider);

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: p.border),
      ),
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.system_update_alt, size: 20, color: p.accentText),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  'Version',
                  style: AppType.caption.copyWith(color: p.secondary),
                ),
              ),
              Text(
                // `—` while the platform answers, like every other value on
                // this screen.
                version?.toString() ?? '—',
                style: AppType.body.copyWith(
                  color: p.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          _body(context, ref, state),
        ],
      ),
    );
  }

  /// What is true right now, and the control that moves it on.
  Widget _body(BuildContext context, WidgetRef ref, UpdateState state) {
    return switch (state) {
      // Nothing checked yet: the button is the whole card body.
      UpdateIdle() => _control(
          context,
          label: 'Check for update',
          onTap: () => _check(context, ref),
        ),
      UpdateChecking() => _working(context, label: 'Checking…'),
      UpdateUpToDate() => _offer(
          context,
          ref,
          caption: "You're on the latest version.",
          label: 'Check for update',
          onTap: () => _check(context, ref),
        ),
      UpdateAvailable(:final release, :final asset) => _offer(
          context,
          ref,
          caption: 'Version ${release.version} is available · ${asset.sizeLabel}',
          label: 'Download update',
          onTap: () => _download(context, ref),
        ),
      UpdateDownloading(:final progress) => _downloading(context, progress),
      UpdateDownloaded() => _offer(
          context,
          ref,
          caption: 'Update downloaded.',
          hint: 'Android will ask you to allow installing from Gymly.',
          label: 'Install update',
          onTap: () => _install(context, ref),
        ),
      UpdateNotInstallable(:final version) => _offer(
          context,
          ref,
          caption: 'Version $version has no file for this phone.',
          label: 'Retry',
          onTap: () => _check(context, ref),
        ),
      UpdateCheckFailed() => _offer(
          context,
          ref,
          caption: "Couldn't check for updates. Check your connection, then "
              'try again.',
          label: 'Retry',
          onTap: () => _check(context, ref),
        ),
    };
  }

  /// Caption (+ optional hint) above the control — the card's one shape.
  Widget _offer(
    BuildContext context,
    WidgetRef ref, {
    required String caption,
    String? hint,
    required String label,
    required VoidCallback onTap,
  }) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(caption, style: AppType.body.copyWith(color: p.text)),
        if (hint != null) ...[
          const SizedBox(height: AppSpace.xs),
          Text(hint, style: AppType.caption.copyWith(color: p.secondary)),
        ],
        const SizedBox(height: AppSpace.md),
        _control(context, label: label, onTap: onTap),
      ],
    );
  }

  /// The card's one control: accent fill, thumb-zone height, press feedback.
  Widget _control(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) =>
      SizedBox(
        height: 48,
        width: double.infinity,
        child: TapScale(
          onTap: onTap,
          child: FilledButton(onPressed: onTap, child: Text(label)),
        ),
      );

  /// A check in flight: the control stays put, disabled, with a spinner where
  /// its label was.
  Widget _working(BuildContext context, {required String label}) {
    final p = context.palette;
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: FilledButton(
        onPressed: null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: p.secondary,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Text(label),
          ],
        ),
      ),
    );
  }

  /// Progress in place of the control: the download owns the card until it
  /// lands. The bar is indeterminate when GitHub sent no length to measure
  /// against.
  Widget _downloading(BuildContext context, double? progress) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 4,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          progress == null
              ? 'Downloading…'
              : 'Downloading… ${(progress * 100).round()}%',
          style: AppType.caption.copyWith(color: p.secondary),
        ),
      ],
    );
  }

  /// Checks, then reports the outcome with one haptic.
  Future<void> _check(BuildContext context, WidgetRef ref) async {
    Haptics.impact();
    await ref.read(updaterProvider.notifier).check();
    switch (ref.read(updaterProvider)) {
      // An offer arrived in place, and a refusal is the other thing the owner
      // has to notice without reading.
      case UpdateAvailable() || UpdateNotInstallable():
        Haptics.impact(strength: HapticStrength.medium);
      case UpdateCheckFailed():
        Haptics.error();
      case _:
        break;
    }
  }

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    Haptics.impact();
    try {
      await ref.read(updaterProvider.notifier).download();
      Haptics.success();
    } on Exception {
      // The card is back on the offer; the failure has to be said out loud.
      Haptics.error();
      if (!context.mounted) return;
      _message(context, "Couldn't download the update. Check your connection, "
          'then try again.');
    }
  }

  Future<void> _install(BuildContext context, WidgetRef ref) async {
    Haptics.impact();
    try {
      await ref.read(updaterProvider.notifier).install();
    } on Exception {
      Haptics.error();
      if (!context.mounted) return;
      _message(context, "Couldn't open the installer. Try again.");
    }
  }

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

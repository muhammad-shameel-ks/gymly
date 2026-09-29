/// Profile: owner identity, gym count, theme mode switcher and logout.
///
/// Reachable at `/profile` (top-level route inside the shell, no bottom tab).
/// Colours come from `context.palette`; sizes from [AppSpace]/[AppRadius].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/theme_mode.dart';
import '../../auth/providers/auth_providers.dart';
import '../../gyms/providers/gyms_providers.dart';

/// Owner profile + appearance + sign-out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final email = ref.watch(authStateProvider).value?.session?.user.email ??
        ref.watch(supabaseClientProvider).auth.currentUser?.email;
    final gymCount = ref.watch(gymsListProvider).value?.length;
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screen,
            AppSpace.sm,
            AppSpace.screen,
            AppSpace.xl,
          ),
          children: [
            _AccountCard(email: email, gymCount: gymCount),
            const SizedBox(height: AppSpace.lg),
            const _SectionLabel('Appearance'),
            const SizedBox(height: AppSpace.sm),
            _ThemeSwitcher(
              mode: mode,
              onChanged: (next) {
                // Segmented control = a discrete value moving.
                Haptics.select();
                ref.read(themeModeProvider.notifier).setThemeMode(next);
              },
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              _themeCaption(mode),
              style: AppType.caption.copyWith(color: p.secondary),
            ),
            const SizedBox(height: AppSpace.lg),
            const _SectionLabel('Account'),
            const SizedBox(height: AppSpace.sm),
            _DangerButton(
              icon: Icons.logout,
              label: 'Log out',
              onTap: () => _confirmLogout(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final p = dialogContext.palette;
        return AlertDialog(
          // Background, radius, border, title and content styles come from
          // the theme's `dialogTheme`.
          title: const Text('Log out?'),
          content: const Text(
            "You'll need to sign in again to manage your gyms.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancel', style: TextStyle(color: p.secondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                // Destructive fill overrides the theme's accent; the label
                // mirrors `ColorScheme.onError`.
                backgroundColor: p.error,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 44),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    await ref.read(authRepositoryProvider).signOut();
    if (!context.mounted) return;
    // Destructive commitment accepted, then the fact — never a bare silent
    // jump to the login screen.
    Haptics.impact(strength: HapticStrength.heavy);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Signed out')));
    context.go('/login');
  }
}

/// Caption under the theme switcher: names what the *current* choice does.
String _themeCaption(ThemeMode mode) => switch (mode) {
      ThemeMode.system => 'Follows your device setting.',
      ThemeMode.dark => 'Always dark.',
      ThemeMode.light => 'Always light.',
    };

/// Gym count in the owner's words: `3 gyms`, `1 gym`, `—` while it loads.
String _gymCountLabel(int? count) => switch (count) {
      null => '—',
      1 => '1 gym',
      _ => '$count gyms',
    };

/// Identity card: avatar, owner email, gym count.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.email, required this.gymCount});

  final String? email;
  final int? gymCount;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.storefront_outlined, color: p.accentText),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Signed in as',
                        style:
                            AppType.caption.copyWith(color: p.secondary)),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      email ?? 'Not signed in',
                      style: AppType.subtitle.copyWith(color: p.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          const Divider(),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Icon(Icons.fitness_center, size: 20, color: p.accentText),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  _gymCountLabel(gymCount),
                  style: AppType.body.copyWith(
                    color: p.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Three-option System / Dark / Light segmented control.
class _ThemeSwitcher extends StatelessWidget {
  const _ThemeSwitcher({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    // Accent fill + onAccent label, surface background, border and text style
    // all come from the theme's `segmentedButtonTheme`.
    return SizedBox(
      height: 48,
      child: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: ThemeMode.system, label: Text('System')),
          ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
          ButtonSegment(value: ThemeMode.light, label: Text('Light')),
        ],
        selected: {mode},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    // Sentence case, per the voice spec — the copy is the label, so it is
    // written as one (no ALL-CAPS transform, no tracking).
    return Text(
      text,
      style: AppType.caption.copyWith(
        color: context.palette.secondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Full-width destructive action (Log out).
class _DangerButton extends StatelessWidget {
  const _DangerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: p.error),
        label: Text(
          label,
          style: AppType.body.copyWith(
            color: p.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: p.error.withValues(alpha: 0.08),
          side: BorderSide(color: p.error.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
    );
  }
}

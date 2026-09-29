/// Owner sign-up (email + password). Creates the Supabase Auth user whose
/// id becomes `gyms.owner_id`.
///
/// Same components and layout as [LoginScreen] (hero → fields → accent CTA) so
/// the two screens stay visually consistent, including the once-per-visit
/// stagger and the outcome haptics ([Haptics.error] refused,
/// [Haptics.success] committed).
///
/// Auth behaviour is unchanged: [AuthRepository.signUp] with
/// [AuthException.message] routed through [authErrorMessage], a voice-spec
/// fallback for unknown failures, and the `_sending` guard. Navigation after a
/// successful sign-up is owned by [authRedirect].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_field.dart';
import '../widgets/auth_hero.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (!_formKey.currentState!.validate()) {
      // Refused: the field errors are the visual pair for this haptic.
      Haptics.error();
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signUp(
            email: _email.text,
            password: _password.text,
          );
      // Committed: the account exists. `authRedirect` bounces the owner to `/`
      // when the auth stream emits — this screen never navigates itself.
      Haptics.success();
    } on AuthException catch (e) {
      Haptics.error();
      if (mounted) setState(() => _error = authErrorMessage(e.message));
    } catch (_) {
      Haptics.error();
      if (mounted) {
        setState(
          () => _error =
              "Couldn't create your account. Check your connection, then try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StaggeredEntrance(
            index: 0,
            child: AuthHero(tagline: 'One account for every gym you run.'),
          ),
          StaggeredEntrance(
            index: 1,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpace.xl),
                  AuthField(
                    controller: _email,
                    label: 'Email',
                    hintText: 'you@gym.com',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Enter a full email address, like you@gym.com.'
                        : null,
                    onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),
                  const SizedBox(height: AppSpace.gap),
                  AuthField(
                    controller: _password,
                    focusNode: _passwordFocus,
                    label: 'Password',
                    hintText: 'At least 6 characters',
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Enter at least 6 characters.'
                        : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpace.md),
                    AuthErrorBanner(message: _error!),
                  ],
                ],
              ),
            ),
          ),
          StaggeredEntrance(
            index: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpace.lg),
                AuthPrimaryButton(
                  label: 'Sign up',
                  busy: _sending,
                  busyLabel: 'Creating your account…',
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpace.sm),
                TapScale(
                  child: TextButton(
                    onPressed: () {
                      // A control was pressed; navigation is the visible change.
                      Haptics.impact();
                      context.go('/login');
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: context.palette.secondary,
                    ),
                    child: const Text('Log in'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

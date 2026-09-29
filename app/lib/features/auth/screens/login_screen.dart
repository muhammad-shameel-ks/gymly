/// Owner login (email + password).
///
/// Premium dark-first layout: [AuthHero] wordmark → themed fields with inline
/// validation → accent pill CTA ([AuthPrimaryButton]) with an in-button progress
/// state, error banner ([AuthErrorBanner]) and a `/signup` link. The three
/// sections stagger in once per visit through the motion layer's
/// [StaggeredEntrance] (index 0/1/2, 250 ms each with a 40 ms stagger, latched
/// per visit and cross-faded under Reduce Motion).
///
/// Auth behaviour is unchanged: [AuthRepository.signIn] with
/// [AuthException.message] routed through [authErrorMessage], a voice-spec
/// fallback for unknown failures, and the `_sending` guard. Navigation after a
/// successful login is owned by [authRedirect] — this screen never calls
/// `go('/')` itself. Haptics are the outcome of the gesture: [Haptics.error] on
/// a refused sign-in, [Haptics.success] once it lands.
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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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
      await ref.read(authRepositoryProvider).signIn(
            email: _email.text,
            password: _password.text,
          );
      // Committed: the session is live. `authRedirect` bounces the owner to `/`
      // when the auth stream emits — this screen never navigates itself.
      Haptics.success();
    } on AuthException catch (e) {
      Haptics.error();
      if (mounted) setState(() => _error = authErrorMessage(e.message));
    } catch (_) {
      Haptics.error();
      if (mounted) {
        setState(
          () => _error = "Couldn't log in. Check your connection, then try again.",
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
            child: AuthHero(tagline: 'Track member dues. Get paid on time.'),
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
                    hintText: 'Your password',
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter your password.' : null,
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
                  label: 'Log in',
                  busy: _sending,
                  busyLabel: 'Logging in…',
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpace.sm),
                TapScale(
                  child: TextButton(
                    onPressed: () {
                      // A control was pressed; navigation is the visible change.
                      Haptics.impact();
                      context.go('/signup');
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: context.palette.secondary,
                    ),
                    child: const Text('Create account'),
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

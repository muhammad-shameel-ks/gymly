/// Gymly entrypoint: Supabase init + preloaded prefs + app shell.
///
/// Supabase credentials come from `--dart-define` (see
/// `core/supabase/supabase_client.dart`); defaults point at the Gymly
/// project so `flutter run` works zero-config.
///
/// Provider unification lives here: the Leads slice declared its own local
/// `selectedGymIdProvider` as an override seam, so the scope below redirects
/// it to the canonical gyms-slice provider. Members/Plans take `gymId`
/// as a constructor param (wired in `app.dart`); Home reads the canonical
/// provider directly. No fourth provider is defined anywhere.
///
/// [SharedPreferences] is loaded before `runApp` and injected, so the
/// persisted [ThemeMode] is known on the first frame (no theme flash).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/supabase/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode.dart';
import 'features/gyms/data/selected_gym.dart' as gyms;
import 'features/leads/application/leads_providers.dart' as leads;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        leads.selectedGymIdProvider.overrideWith(
          (ref) => ref.watch(gyms.selectedGymIdProvider),
        ),
      ],
      child: const GymlyApp(),
    ),
  );
}

class GymlyApp extends ConsumerWidget {
  const GymlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Gymly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
    );
  }
}

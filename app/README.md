# gymly — app

The Flutter client. Product overview, features and downloads: [../README.md](../README.md).

```bash
flutter pub get
flutter run            # uses the bundled public Supabase project
flutter test
flutter analyze
```

Point it somewhere else with
`--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`.

Layout: `lib/features/<feature>/` (data, providers, screens, widgets),
`lib/core/` (theme, motion, brand signature, shared widgets, Supabase client).
The product and UX contract is [../DESIGN.md](../DESIGN.md) and the vocabulary is
[../GLOSSARY.md](../GLOSSARY.md).

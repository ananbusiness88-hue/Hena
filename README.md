# Hena

Hena is a Flutter marketplace application backed by Supabase.

## Environment configuration

From the repository root, create local environment files using PowerShell:

```powershell
Copy-Item .env.example .env
Copy-Item .env.example .env.production
Edit both files and replace the example values with the correct URL and publishable key for each Supabase environment.

- `.env` is used for local mode.
- `.env.production` is used when building with `--dart-define=SUPABASE_MODE=production`.
- Start local Supabase with `supabase start` and inspect its configuration with `supabase status`.
- Do not commit real environment files or put Supabase secret/service_role keys in the Flutter app.
- Android builds also require the intended Firebase configuration.

## Verify the source

```powershell
flutter pub get
flutter analyze
flutter test
```

## Run locally

After configuring `.env` and starting the required local services:

```powershell
flutter run
```

## Build production Android APK

After configuring `.env.production`:

```powershell
flutter build apk --release --dart-define=SUPABASE_MODE=production
```

Review the migrations in `supabase/migrations` before applying database changes to any environment.
# YKS Level

Gamified YKS / TYT / AYT practice app for students in Turkey. Duolingo-style
daily quests, XP, levels, streaks, weekly leagues and achievements wrapped
around a fast question-solving loop.

- **Platform:** Android (iOS project scaffolded, not verified)
- **UI language:** Turkish (all user-facing strings live in `lib/l10n/app_tr.arb`)
- **Code language:** English

---

## Table of contents

1. [Project overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [Requirements](#3-requirements)
4. [Flutter setup](#4-flutter-setup)
5. [Supabase setup](#5-supabase-setup)
6. [Firebase setup](#6-firebase-setup)
7. [AdMob setup](#7-admob-setup)
8. [Google Play Billing setup](#8-google-play-billing-setup)
9. [Environment variables](#9-environment-variables)
10. [Running a development build](#10-running-a-development-build)
11. [Running tests](#11-running-tests)
12. [Android release setup](#12-android-release-setup)
13. [Generating the AAB](#13-generating-the-aab)
14. [Google Play launch checklist](#14-google-play-launch-checklist)
15. [Importing questions](#15-importing-questions)
16. [Database schema](#16-database-schema)
17. [Known limitations](#17-known-limitations)
18. [Future improvements](#18-future-improvements)

---

## 1. Project overview

### The core loop

```
Home  →  Daily quest  →  Quiz  →  XP  →  Level / Streak  →  come back tomorrow
```

Everything in the product serves that loop. The home screen is the most
important surface: greeting, streak, level card, today's quests, the daily
question, a fact of the day and today's stats.

### Feature map

| Area | What ships |
| --- | --- |
| Onboarding | 3 screens, shown once |
| Auth | Supabase email + Google OAuth + **guest mode** |
| Study | Subject cards → topics → 10-question sessions |
| Quiz | Instant feedback, explanations, combo system, haptics |
| Progression | XP (`round(100 · level^1.25)`), levels, streaks, 4 daily quests |
| Social | Weekly XP leaderboard (top 50 + your own rank), 5 leagues |
| Achievements | 7 achievements with progress bars |
| Monetization | Rewarded ad (bonus XP), capped interstitials, `premium_monthly` subscription |
| Telemetry | Firebase Analytics (17 events) + Crashlytics |
| Retention | Local daily reminder, default 19:00 |

### Runs with zero backend

The app is **local-first and works fully offline out of the box**. With no
Supabase, Firebase or AdMob configuration it still runs the entire study loop
using the bundled demo content in `assets/seed/`. Every integration degrades
gracefully — that is what makes `git clone && flutter run` work.

What you lose without a backend: the leaderboard, cross-device sync and real
ads/subscriptions.

---

## 2. Architecture

Simple, feature-first. No Clean Architecture ceremony.

```
lib/
  main.dart                  # bootstrap: env, timezone, Firebase, Supabase, store
  app.dart                   # MaterialApp.router, theme, l10n, post-frame service init
  core/
    config/app_config.dart   # ALL branding + credentials + product ids
    theme/                   # palette + Material 3 themes (light & dark)
    utils/tr_date.dart       # every Europe/Istanbul day/week boundary
    widgets/                 # AppCard, XpProgressBar, badges, state views
    l10n_maps.dart           # domain id → Turkish string / icon / colour
  domain/                    # PURE game rules, no Flutter imports
    xp.dart  streak.dart  combo.dart  league.dart
    daily_quest.dart  achievement.dart
    progress_engine.dart     # the reducer: session → new state + rewards
  data/
    models/                  # plain immutable classes with manual JSON
    content_repository.dart  # Supabase source + bundled asset fallback
    leaderboard_repository.dart
    sync_service.dart        # best-effort mirror of local state to Supabase
  services/                  # local_store, auth, analytics, ads, billing,
                             # notifications, feedback (haptics/sound)
  state/                     # Riverpod providers and controllers
  routing/                   # GoRouter + bottom-nav shell
  features/                  # one folder per screen
    onboarding/ auth/ home/ study/ quiz/ leaderboard/
    profile/ achievements/ premium/ settings/
  l10n/app_tr.arb            # every user-facing string
```

### Three decisions worth knowing

**1. Local-first, cloud-mirrored.** `SharedPreferences` holds the authoritative
game state; Supabase is a mirror for sync and the leaderboard. This keeps the
app instant and offline-tolerant, keeps backend cost near zero (one write per
session, not per answer), and makes guest mode free — there is no separate
"guest data model" to merge later.

**2. All game rules are pure functions.** `lib/domain/` imports nothing from
Flutter or Riverpod. `ProgressEngine.applySession()` takes a state and a quiz
result and returns a new state plus a `SessionRewards` describing what to
celebrate. That is why the rules are cheap to unit test and hard to get subtly
wrong.

**3. Every integration is optional.** Analytics, ads, billing, notifications,
Supabase and Firebase all no-op cleanly when unconfigured. Premium users get a
`NoopAdService` so the rest of the app never branches on entitlement.

### Manual JSON, no code generation

`freezed`/`json_serializable` were deliberately skipped. There are ~8 models
with hand-written `toJson`/`fromJson`; adding `build_runner` would cost more
build time than it saves. Localization is the only codegen (`flutter gen-l10n`,
run automatically by `flutter pub get`).

### iOS

The iOS project is scaffolded and no Android-only APIs leak into shared code,
so a port is mostly platform configuration (Firebase plist, AdMob ids, StoreKit
products). It has **not** been built or tested.

---

## 3. Requirements

| Tool | Version used |
| --- | --- |
| Flutter | 3.47.0 (stable) |
| Dart | 3.13.0 |
| JDK | 17 (21 also works) |
| Android SDK | compileSdk 36, minSdk 23 |
| Python | 3.10+ (import scripts only) |

```bash
flutter --version
flutter doctor
```

---

## 4. Flutter setup

```bash
git clone <your-repo-url> yks-level
cd yks-level

# Installs packages and generates lib/l10n/app_localizations*.dart
flutter pub get

# Run it — works immediately, no credentials needed
flutter run
```

> `lib/l10n/app_localizations*.dart` is generated and git-ignored. If your IDE
> shows missing-import errors on a fresh clone, run `flutter pub get`
> (or `flutter gen-l10n`).

---

## 5. Supabase setup

Optional but needed for the leaderboard and cross-device sync.

### 5.1 Create the project

1. Create a project at <https://supabase.com/dashboard>.
2. Copy **Project URL** and the **anon / publishable** key from
   Settings → API.

### 5.2 Apply the schema

In the dashboard SQL Editor, run these **in order**:

```
supabase/migrations/0001_init.sql      -- tables, indexes, triggers
supabase/migrations/0002_rls.sql       -- row level security
supabase/migrations/0003_functions.sql -- leaderboard view + RPCs
supabase/seed.sql                      -- catalogue + 60 demo questions
```

With the Supabase CLI instead:

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
psql "$DATABASE_URL" -f supabase/seed.sql
```

### 5.3 Configure auth

**Email:** Authentication → Providers → Email. For a fast MVP launch, turn
*Confirm email* **off** (users can start solving immediately); turn it on before
you care about fake signups.

**Google:** Authentication → Providers → Google.

1. Create an OAuth client in the [Google Cloud console](https://console.cloud.google.com/apis/credentials).
2. Paste the client id/secret into Supabase.
3. Add this redirect URL under Authentication → URL Configuration → Redirect URLs:

   ```
   com.example.ykslevel://login-callback
   ```

   It must match `AppConfig.authRedirectUrl` and the `intent-filter` in
   `android/app/src/main/AndroidManifest.xml`. **Change all three together when
   you change the package name.**

> Google sign-in goes through Supabase's OAuth redirect in an external browser
> rather than the native `google_sign_in` SDK. That trades a slightly less slick
> flow for no SHA-1 fingerprint management, no extra client ids in the app, and
> a simpler iOS port later.

### 5.4 Point the app at it

Fill in `.env` (see [section 9](#9-environment-variables)):

```
SUPABASE_URL=https://YOUR-PROJECT.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...
```

---

## 6. Firebase setup

Optional. Without it the app runs and analytics calls become no-ops.

1. Create a project at <https://console.firebase.google.com>.
2. Add an Android app with package name `com.example.ykslevel`
   (or your production id).
3. Download `google-services.json` → put it at **`android/app/google-services.json`**.
4. Enable **Analytics** and **Crashlytics** in the console.

That is the whole setup. `android/app/build.gradle.kts` applies the Google
Services and Crashlytics Gradle plugins **only when that file exists**, so a
fresh clone without Firebase still builds. `Firebase.initializeApp()` is wrapped
in a try/catch for the same reason.

`google-services.json` is git-ignored — it is per-project configuration, not a
secret, but there is no reason to commit it.

### Verifying Crashlytics

Crashlytics collection is disabled in debug builds (`kDebugMode`). To test:

```bash
flutter build apk --release
flutter install
# force a crash in the app, then reopen it — reports upload on next launch
```

---

## 7. AdMob setup

**Development builds always use Google's official test ad units.** There is no
way to accidentally serve live ads from a debug build.

### Going live

1. Create an app in [AdMob](https://apps.admob.com) and note the **App ID**
   (`ca-app-pub-XXXX~YYYY`).
2. Create two ad units: one **Rewarded**, one **Interstitial**.
3. Provide them at build time — never in source:

   ```bash
   export ADMOB_ANDROID_APP_ID="ca-app-pub-XXXX~YYYY"

   flutter build appbundle \
     --dart-define=APP_ENV=production \
     --dart-define=ADMOB_REWARDED_AD_UNIT_ID=ca-app-pub-XXXX/AAAA \
     --dart-define=ADMOB_INTERSTITIAL_AD_UNIT_ID=ca-app-pub-XXXX/BBBB
   ```

   `ADMOB_ANDROID_APP_ID` is read by Gradle into the manifest placeholder;
   it also accepts `admobAppId` in `android/key.properties`.

### Ad policy in this app

| Placement | Rule |
| --- | --- |
| Rewarded ("Bonus XP Kazan") | Opt-in only, after a session. XP is granted **only** on the SDK's user-earned-reward callback, never on dismissal. Worth ~25% of session XP. |
| Interstitial | Max one per **3 completed sessions** (`AdMobService.interstitialSessionInterval`), counter persisted across launches. |
| Banner | Not used. |
| Premium users | See zero ads — `adServiceProvider` returns `NoopAdService`. |
| Load failure | Silently ignored; the CTA simply does not appear. |

Set `ADS_ENABLED=false` in `.env` to disable the ads SDK entirely (handy for
screenshots).

---

## 8. Google Play Billing setup

### Decision: plain Google Play Billing, not RevenueCat

RevenueCat was evaluated and **not** adopted for the MVP:

- there is exactly **one** product (`premium_monthly`) on **one** platform, so
  its main value — cross-platform entitlement reconciliation — does not apply
  yet;
- `in_app_purchase` covers purchase, restore and localized pricing in ~200
  lines (`lib/services/billing_service.dart`);
- it avoids a third-party dependency in the payment path and its revenue share
  above the free tier.

Revisit when iOS ships or when server-side entitlement gets painful.
`BillingService` exposes a `PremiumState` enum (`free` / `premium` /
`gracePeriod` / `expired`) so swapping the source of truth touches one class.

### Play Console setup

1. Upload at least one build to **Internal testing** first — you cannot create
   subscriptions before an app bundle exists.
2. Monetize → Subscriptions → **Create subscription**
   - Product ID: **`premium_monthly`** (must match `AppConfig.premiumProductId`)
   - Add a base plan: monthly, auto-renewing
   - Set prices per country. **Never hardcode a price in the app** — it is
     fetched from Play and shown as `{price} / ay`.
3. Add licence testers: Setup → License testing. Testers can subscribe without
   being charged.

### Current limits

The client trusts Google Play's purchase state and caches the entitlement
locally, so a premium user is never shown an ad while the store round-trips on
a cold start. Real `gracePeriod` / `expired` detection needs the Play Developer
API server-side; the `subscriptions` table already has `purchase_token`,
`expires_at` and `verified_at` columns for it.

---

## 9. Environment variables

`.env` is committed **with empty values** because `pubspec.yaml` declares it as
an asset and the build fails without it. It may only ever hold *publishable*
client identifiers — the Supabase anon key and AdMob unit ids ship inside the
APK anyway and are not secrets.

| Key | Purpose |
| --- | --- |
| `SUPABASE_URL` | Project URL. Empty ⇒ fully offline mode. |
| `SUPABASE_ANON_KEY` | Publishable anon key. |
| `ADMOB_ANDROID_APP_ID` | Read by Gradle, not by Dart. |
| `ADMOB_REWARDED_AD_UNIT_ID` | Production only. |
| `ADMOB_INTERSTITIAL_AD_UNIT_ID` | Production only. |
| `ADS_ENABLED` | `false` disables the ads SDK. |

`--dart-define` overrides `.env`, so CI can inject configuration without ever
writing it to disk. **Real secrets never go here:** the Supabase service-role
key and the signing keystore belong in CI secrets and
`android/key.properties` (both git-ignored).

### Environments

Selected with `--dart-define=APP_ENV=...`; there is no Gradle flavor system.

| | `development` (default) | `production` |
| --- | --- | --- |
| Ad units | Google test units | from config |
| Logging | verbose (`AppConfig.verboseLogging`) | quiet |
| Crashlytics | off in debug | on |

---

## 10. Running a development build

```bash
flutter run                       # debug, test ads, verbose logs
flutter run --release             # release-mode performance check
flutter run --dart-define=APP_ENV=production   # production config locally
```

---

## 11. Running tests

```bash
flutter analyze                   # must be clean
flutter test                      # 72 tests
flutter test test/domain          # game rules only
flutter test --coverage
```

Coverage is deliberately focused on the rules that break silently:

| File | Covers |
| --- | --- |
| `test/domain/xp_test.dart` | level curve, XP per answer, combo tiers, rewarded-ad bonus |
| `test/domain/streak_test.dart` | streak transitions + **Europe/Istanbul day and week boundaries** |
| `test/domain/progress_engine_test.dart` | session application, quest auto-claim, level-up, achievements, leagues |
| `test/domain/premium_test.dart` | entitlement states, cached entitlement |
| `test/domain/ad_reward_test.dart` | interstitial frequency cap |
| `test/widget/quiz_test.dart` | answer interaction and locked states |
| `test/widget/home_test.dart` | loading / error / guest states |
| `test/widget/premium_test.dart` | paywall states and localized pricing |

---

## 12. Android release setup

### 12.1 Change the application id

`com.example.ykslevel` is a **placeholder** and Google Play will reject it.
Change it in all four places:

1. `android/app/build.gradle.kts` → `namespace` **and** `applicationId`
2. `android/app/src/main/AndroidManifest.xml` → the `data android:scheme` of
   the login-callback intent-filter
3. `lib/core/config/app_config.dart` → `packageName`
4. Move `android/app/src/main/kotlin/com/example/ykslevel/MainActivity.kt` to
   the matching directory and update its `package` line

Then update the Supabase redirect URL (section 5.3).

### 12.2 Create an upload keystore

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Back this file up. Losing it means you can never update the app again (unless
Play App Signing is enabled — it is, by default, and worth keeping on).

### 12.3 Wire up signing

```bash
cp android/key.properties.example android/key.properties
```

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

`android/key.properties` is git-ignored. When it is absent, release builds fall
back to the debug keystore so local release builds still work — but such a
build **cannot** be uploaded to Play.

### 12.4 Other launch edits

- `pubspec.yaml` → `version: 1.0.0+1` (bump `+N` for every upload)
- `android/app/src/main/res/mipmap-*/ic_launcher.png` → your icon
- `android/app/src/main/AndroidManifest.xml` → `android:label` (currently
  "YKS Level")
- `lib/core/config/app_config.dart` → `supportEmail`, `privacyPolicyUrl`,
  `termsUrl`

---

## 13. Generating the AAB

```bash
flutter clean
flutter pub get
flutter build appbundle \
  --dart-define=APP_ENV=production \
  --dart-define=ADMOB_REWARDED_AD_UNIT_ID=ca-app-pub-XXXX/AAAA \
  --dart-define=ADMOB_INTERSTITIAL_AD_UNIT_ID=ca-app-pub-XXXX/BBBB
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Test the exact artifact Play will serve:

```bash
# https://github.com/google/bundletool
bundletool build-apks --bundle=build/app/outputs/bundle/release/app-release.aab \
  --output=app.apks --connected-device
bundletool install-apks --apks=app.apks
```

Release builds have R8 minification and resource shrinking on; rules are in
`android/app/proguard-rules.pro`.

> **Not verified in this environment.** `flutter analyze`, `flutter test` and
> `flutter build bundle` (Dart compile + asset bundling) all pass, but
> `flutter build appbundle` could not be run here because `dl.google.com` — the
> Android SDK and Google Maven host — is blocked by network policy in the
> environment this project was built in. Run it once locally before your first
> upload.

---

## 14. Google Play launch checklist

### Before the first upload

- [ ] Application id changed from `com.example.*` (section 12.1)
- [ ] Upload keystore created and **backed up**
- [ ] `android/key.properties` configured
- [ ] App icon and label replaced
- [ ] Privacy policy published at a public URL and set in `AppConfig`
- [ ] Terms published and set in `AppConfig`
- [ ] `supportEmail` is a mailbox you actually read

### Store listing

- [ ] App name (30 chars), short description (80), full description (4000)
- [ ] Feature graphic **1024×500 PNG/JPG** (required)
- [ ] At least **2** phone screenshots, 16:9 or 9:16, min 320px on the short side
  — suggested: home screen, quiz feedback, result screen, leaderboard, profile
- [ ] App icon 512×512 PNG
- [ ] Category: **Education**
- [ ] Turkish (`tr-TR`) as the default listing language

### Policy declarations

- [ ] **Data safety form.** Declare what `docs/privacy_policy.md` describes:
  email address, user id, app interactions, crash logs, diagnostics, purchase
  history. Data is encrypted in transit; users can request deletion in-app.
- [ ] **Ads declaration:** *Yes, this app contains ads.*
- [ ] **Content rating** questionnaire → expect **Everyone / 3+**. Answer the
  ads question truthfully.
- [ ] **Target audience:** 13+ (the app is for university-entrance candidates).
  Do **not** opt into Families/Designed-for-Families — it adds ad-network
  restrictions you do not need.
- [ ] **Account deletion URL / in-app path.** Required since 2023. This app
  ships in-app deletion at `Profil → Ayarlar → Hesabı Sil`, backed by the
  `delete_account` RPC. Also provide a web deletion request form.
- [ ] **Financial features:** none.
- [ ] **Government app:** no.

### Policy risks specific to this app

| Risk | Mitigation in place |
| --- | --- |
| **Copyright** — ÖSYM questions are protected | Only original demo content ships. `docs/question_import.md` states the rule; `source_type` tracks provenance. Do not import scraped questions. |
| **Impersonation** — implying an ÖSYM affiliation | `docs/terms.md` §2 disclaims it. Keep it out of the store listing, icon and screenshots. |
| **Misleading claims** — "guaranteed success" | Avoid in listing copy; disclaimed in terms §4. |
| **Ad policy** — interstitials at unexpected moments | Capped at 1 per 3 sessions, never mid-quiz, never on app open. |
| **Subscription clarity** | Price, renewal terms and cancellation path shown on the paywall before purchase. |
| **Data safety mismatch** | Keep the form in sync with the analytics events in `lib/services/analytics_service.dart`. |

### Rollout

1. **Internal testing** — up to 100 testers, available in minutes. Verify
   billing with licence testers here.
2. **Closed testing** — Google now requires a sustained closed test (for
   personal developer accounts: **12 testers opted in for 14 continuous days**)
   before production access. Check current Play Console requirements; start
   this early, it is the long pole.
3. **Production** — staged rollout at 20% → 50% → 100%, watching Crashlytics
   and the ANR/crash-rate vitals between steps.

### Measure from day one

The events for these are already wired:

| Metric | Source events |
| --- | --- |
| Onboarding completion | `onboarding_started` → `onboarding_completed` |
| First quiz completion | `quiz_completed` (first per user) |
| D1 / D7 retention | Firebase retention report + `app_open` |
| Questions per user per day | `question_answered` |
| Sessions per user per day | `quiz_started` |
| Rewarded-ad opt-in rate | `rewarded_ad_completed` / `rewarded_ad_offered` |
| Premium conversion | `subscription_success` / `premium_screen_viewed` |

---

## 15. Importing questions

See **[docs/question_import.md](docs/question_import.md)** for the full format
and workflow.

```bash
# validate + generate SQL
python3 scripts/import_questions.py --input my_questions.csv --sql out.sql

# or upload directly (service-role key required)
export SUPABASE_URL="https://YOUR-PROJECT.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="eyJ..."
python3 scripts/import_questions.py --input my_questions.csv --upload

# regenerate the bundled demo seed after editing assets/seed/*.json
python3 scripts/generate_seed.py
```

> **Never import official ÖSYM questions.** The bundled 60-question bank is
> original demo content.

---

## 16. Database schema

Migrations live in `supabase/migrations/`.

### Content (public read, no user writes)

| Table | Purpose |
| --- | --- |
| `subjects` | Subject catalogue, `code` is the stable key used by the app |
| `topics` | Topics per subject |
| `questions` | Question bank. `external_id` makes imports idempotent. |
| `app_content` | Daily facts ("Bugünün Bilgisi") and future CMS copy |
| `daily_quests` | Quest catalogue (fixed set in the MVP) |
| `achievements` | Achievement catalogue |

### User-owned (RLS: owner only)

| Table | Purpose |
| --- | --- |
| `profiles` | Username, avatar, total XP, streaks, exam track, premium status |
| `study_sessions` | One row per completed quiz session |
| `question_attempts` | One row per answer: selection, correctness, response time, XP |
| `daily_progress` | Per-day solved / correct / XP, keyed by Istanbul date |
| `user_daily_quests` | Per-day quest progress |
| `weekly_xp` | XP per Monday-anchored week — the leaderboard's source |
| `user_achievements` | Unlocked achievements |
| `subscriptions` | Play entitlement mirror, ready for server-side verification |

### Views and functions

| Object | Purpose |
| --- | --- |
| `weekly_leaderboard` | Curated public projection: user id, username, avatar, weekly XP. Nothing else about a profile leaks. |
| `weekly_rank(uuid, date)` | The current user's rank when they are outside the top 50 |
| `delete_account()` | `SECURITY DEFINER` account deletion; cascades everywhere |
| `handle_new_user()` | Creates a `profiles` row on signup |

### Security model

`supabase/migrations/0002_rls.sql` enables RLS on **every** table.

- Content tables: `select` only, no insert/update/delete policy exists, so the
  anon and authenticated roles can never modify the question bank.
- User tables: all four verbs gated on `auth.uid() = user_id`.
- `profiles`: readable only by its owner. Public leaderboard data is served by
  the `weekly_leaderboard` view instead of a permissive profile policy.

### Date semantics

Every `day` / `week_start` column is a plain `date` already normalised to
**Europe/Istanbul** by the client (`lib/core/utils/tr_date.dart`). Weeks start
Monday. This is the single most bug-prone part of the app and it has dedicated
tests in `test/domain/streak_test.dart`.

---

## 17. Known limitations

Honest list of what the MVP does *not* do.

1. **Guest → account merge is one-directional.** Signing in keeps your local
   progress and pushes it up. If the cloud profile has *more* XP (an old
   account on a new device), the cloud wins and local progress is replaced. No
   field-by-field merge, no conflict UI.
2. **Sync is fire-and-forget.** A push that fails on a flaky network is not
   retried and that session's rows are lost server-side. Local state stays
   correct, so the user never notices. Add an outbox when server data starts
   mattering.
3. **Subscription state is client-trusted.** No server-side receipt
   verification, so `gracePeriod` and `expired` are modelled but never actually
   detected. A determined user could fake premium locally.
4. **No offline quiz mode by design.** Sessions need questions; if Supabase is
   configured but unreachable, the app silently falls back to the bundled demo
   bank rather than showing an error.
5. **Questions are fetched, not cached to disk.** In-memory cache only, reset on
   app restart. Fine for a small bank; revisit at thousands of questions.
6. **Daily quests are a fixed set.** The schema supports date-based rotation,
   the client does not use it yet.
7. **Leagues have no promotion/relegation.** League is derived purely from
   weekly XP thresholds — there is no cohort or matchmaking.
8. **Leaderboard shows the top 50 without pagination**, plus your own row.
9. **Subject progress % is motivational, not academic.** It is
   `solved / 200` (`kSubjectMasteryTarget`), not a mastery model.
10. **Reminders use inexact alarms.** Deliberate: exact alarms need extra Play
    Console justification and a reminder does not need minute precision.
11. **iOS is scaffolded but untested.**
12. **Only Turkish ships.** The l10n infrastructure supports more; add
    `lib/l10n/app_<locale>.arb` and the locale appears automatically.
13. **`flutter build appbundle` was not run in the build environment** — see
    section 13.

---

## 18. Future improvements

Roughly in the order they would earn their keep.

**Retention**
- Streak freeze / repair (Duolingo's single highest-impact retention feature)
- Push notifications (FCM) for streak-at-risk moments, not just a fixed time
- Weekly recap: "Bu hafta 143 soru çözdün"

**Content**
- Wrong-answer review queue and spaced repetition
- Per-topic mastery from real accuracy instead of a solved-count proxy
- Enable the AYT subjects (schema is ready, content is not)

**Monetization**
- Server-side receipt verification (Play Developer API) → real grace/expired
- Annual plan and a free trial
- Paywall A/B tests once volume justifies them

**Social**
- Friends and private leagues
- Real league promotion/relegation cohorts

**Engineering**
- Sync outbox with retry
- Disk cache for questions
- Golden tests for the home and result screens
- CI: `flutter analyze` + `flutter test` + AAB build on every PR

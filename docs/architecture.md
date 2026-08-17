# Architecture notes

Companion to README §2. This is the "why", for whoever touches the code next.

## Data flow of the core loop

```
 StudyScreen ──▶ TopicListScreen ──▶ QuizScreen
                                        │
                       answers accumulate locally
                       (combo, XP, attempts, timing)
                                        │
                                        ▼
                       ProgressController.applySession(QuizResult)
                                        │
                    ┌───────────────────┼────────────────────┐
                    ▼                   ▼                    ▼
           ProgressEngine        AnalyticsService       SyncService
        (pure state reducer)     (quiz_completed,      (fire-and-forget
                    │             level_up, …)          Supabase mirror)
                    ▼
              LocalStore (SharedPreferences)  ← source of truth
                    │
                    ▼
             SessionRewards ──▶ QuizResultScreen
                                (level-up dialog, achievement toasts,
                                 streak banner, rewarded-ad offer)
```

One write per session, not per answer. That is what keeps the Supabase free tier
comfortable and the UI instant.

## Why the engine is a pure reducer

`ProgressEngine.applySession()` is a single function that takes
`(UserProgress, QuizResult, todayKey)` and returns `(UserProgress, SessionRewards)`.

It fixes an ordering that is easy to get wrong by hand:

1. roll the day over if the Istanbul date changed
2. add session stats (solved, correct, subject stats, study day)
3. add session XP to total + weekly buckets
4. evaluate and **auto-claim** daily quests → more XP
5. evaluate the streak (needs step 2's updated daily count)
6. evaluate achievements (needs steps 2 and 5)
7. compute level before/after across *all* XP added

Because it is pure, `test/domain/progress_engine_test.dart` can assert each of
these directly with no widgets, no mocks and no async.

## Timezone handling

`TrDate` is the only place that knows about Europe/Istanbul.

- `TrDate.todayKey()` → `yyyy-MM-dd` for the current Istanbul day
- `TrDate.weekStartKey()` → the Monday of the current Istanbul week
- `TrDate.clock` is a swappable function so tests can pin "now"

Never call `DateTime.now()` for gameplay decisions. The one intentional
exception is the home screen greeting (Günaydın / İyi günler / İyi akşamlar),
which should follow the *device* clock, not Istanbul.

## Provider graph

```
localStoreProvider          (overridden in main after async init)
supabaseClientProvider      (overridden in main; null ⇒ offline mode)
analyticsProvider           (overridden in main when Firebase initialised)
        │
        ├─ authServiceProvider ─── authStateProvider ─── currentUserProvider
        ├─ contentRepositoryProvider ─── subjectsProvider / dailyQuestionProvider
        ├─ leaderboardRepositoryProvider ─── leaderboardProvider
        ├─ syncServiceProvider
        ├─ billingServiceProvider ─── premiumStatusProvider ─── isPremiumProvider
        │                                                            │
        │                                                   adServiceProvider
        │                                            (Noop when premium)
        ├─ settingsControllerProvider ─── feedbackServiceProvider
        ├─ progressControllerProvider ─── levelProvider
        │                                 visibleStreakProvider
        │                                 dailyQuestsProvider
        │                                 leagueProvider
        │                                 achievementStatsProvider
        └─ appFlowControllerProvider ─── routerProvider (redirects)
```

Everything is a plain `Provider` / `NotifierProvider` — no `riverpod_generator`,
no code generation.

## Router redirects

`appFlowControllerProvider` drives a three-gate funnel:

```
!onboardingCompleted  →  /onboarding
!authGateCompleted    →  /auth        (satisfied by signing in OR choosing guest)
!profileReady         →  /setup       (username is empty)
otherwise             →  the shell (/home, /study, /league, /profile)
```

"Sign in" from Settings or a guest CTA calls `resetAuthGate()`, which drops the
user back onto `/auth` through the same redirect rather than through ad-hoc
navigation.

## Graceful degradation matrix

| Missing | Effect |
| --- | --- |
| `.env` values | Bundled demo content, guest-only, no leaderboard |
| `google-services.json` | Gradle plugins not applied; analytics/Crashlytics no-op |
| AdMob config | Google test ads in dev; no ads if load fails |
| Play Billing | Paywall shows "Şu an kullanılamıyor"; app fully usable |
| Network | Content falls back to bundled assets; sync retries next session |

The rule: **no integration may ever block the study loop.**

## Adding a feature

1. Pure rules → `lib/domain/` (+ a test)
2. Persisted state → a field on `UserProgress` (bump `toJson`/`fromJson`)
3. Strings → `lib/l10n/app_tr.arb`, then `flutter gen-l10n`
4. Domain id → Turkish mapping → `lib/core/l10n_maps.dart`
5. Screen → `lib/features/<feature>/`
6. Route → `lib/routing/app_router.dart`
7. Analytics → a constant in `AnalyticsEvents`, never a bare string

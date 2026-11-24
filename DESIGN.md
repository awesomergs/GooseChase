# GooseChase design system

_Restructured 2026-11-19 around the unified design system proposed in `docs/phase0/THEME_MERGE_PLAN.md`. Much of the guidance below (native-first rules, typography and spacing tokens, the glass rules, camera overlays, accessibility acceptance) is Cody's from the hackathon `DESIGN.md`, kept and re-pointed at the GooseChase brand. Where the code does not match yet, the merge plan says how to get there._

## 1. Direction

**Sky, grass and a goose.** Bright, playful and native to iOS. The look comes straight from the app icon: a sky-blue world, a strip of rolling grass, and an orange-legged goose who reacts to what is happening. Orange is reserved for the one main action on a screen; green means cleared.

- iOS decides how things *work* (navigation, sheets, lists, forms, tab bar). This system decides how they *look*.
- Personality comes from the sky/grass scene, the goose and SF Rounded, never from custom chrome.
- The app window is light-only (`GooseChaseApp` sets `.preferredColorScheme(.light)`); the camera is always dark.

## 2. Native Apple foundation (Cody)

Follow [Apple's Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines). Prefer `NavigationStack`, native titles and toolbars, `List`, `Form`, standard `Button`s, system sheets and a full-screen camera. Keep native back gestures, safe areas, sheet dismissal, keyboard avoidance, text editing and focus behavior. Use real `Button`s and `NavigationLink`s, not gesture-only substitutes. Destructive actions use the native destructive role. Let system navigation bars, toolbars and the tab bar keep their default appearance; brand the content beneath the chrome.

## 3. Color

One palette: `Brand` in `GooseChase/Design/Theme.swift`. The roles marked _(planned)_ come from the merge plan and replace `QuarryTheme`.

| Token | Hex | Use |
|---|---|---|
| `Brand.sky` | `#3FA2E0` | Sky gradient (top), app tint, tab bar selection |
| `Brand.skyLight` | `#5BB8EC` | Sky gradient (bottom) |
| `Brand.skyDeep` _(planned)_ | `#1F6FA5` | Tinted cards and pills that carry white text (5.4:1) |
| `Brand.orange` | `#F28C28` | **The one main action** per screen (`.gooseProminent()`), goose beak and legs |
| `Brand.grass` / `grassDark` | `#5DBB63` / `#4CA554` | Grass scene, cleared progress segments, checkmark fills. Decoration only: never text |
| `Brand.ink` | `#1E2A33` | Primary text, label on orange buttons (5.97:1) |
| `Brand.wing` | `#D5DEE5` | Goose wing, neutral fills |
| `Brand.canvas` _(planned)_ | `#F4F9FD` | Page background under lists |
| `Brand.surface` _(planned)_ | white | Content cards |
| `Brand.textSecondary` _(planned)_ | `#5B6B76` | Supporting copy on canvas/cards (5.2:1) |
| `Brand.success` _(planned)_ | `#2F7A3A` | "Ready", "Cleared", "Verified" text and icons on light surfaces (5.3:1) |
| `Brand.warning` _(planned)_ | system orange | "Needs photos" and connection warnings, always with a symbol |
| `Brand.Camera.*` _(planned)_ | black scrim, white text, orange accent, `#8EC9A5` success | Camera overlays on live video |

Rules:

- Orange signals the main action or selection. Avoid decorative orange borders and large orange backgrounds.
- Green means cleared/verified, never "promising score". Pair it with a checkmark and the word.
- **White text on `Brand.sky` is only 2.8:1.** Put body text on a card (`.brandCard`) or on `skyDeep`; large headlines directly on the sky need a subtle shadow and an on-device check with Increased Contrast.
- Contrast targets (Cody): 4.5:1 normal text, 3:1 large text and essential control edges/status graphics. Don't lower text opacity to make hierarchy.
- Errors use system red with a label and symbol.
- The widget extension can't see `Brand`; it mirrors these values by hand (`ActivityGoose`, `QuarryWidgetsLiveActivity`). Keep them in sync or share a palette file (merge plan step 13).

## 4. Typography

**SF Rounded everywhere**, set once with `.fontDesign(.rounded)` at the app root, using text styles (never fixed sizes for text, except the two deliberate display numbers, which should scale with `@ScaledMetric`).

| Role | Style | Treatment |
|---|---|---|
| Native screen title | system navigation title | Let `NavigationStack` style it |
| Tab header title | `.largeTitle` heavy | White on the sky scene |
| Current clue | `.title2` bold | Unlimited lines, never truncated |
| Completion headline | `.largeTitle` bold | Wraps naturally |
| Hunt title / section heading | `.headline` / `.title2` bold | |
| Body, inputs, buttons | `.body` / `.headline` | Sentence case |
| Supporting metadata | `.subheadline` | `textSecondary`; don't shrink to fit |
| Timers, counts, room code | monospaced digits | Meaningful spoken label |
| Countdown (130 pt), room code (44 pt) | display | Wrap in `@ScaledMetric` |

## 5. Spacing and shape (`Metrics`, from Cody's tokens)

| Token | Value |
|---|---|
| Spacing scale | 4, 8, 12, 16, 24, 32 pt |
| `related` (text gap) | 8 |
| `item` (card-to-card) | 12 |
| `cardPadding` | 16 (20 for the main clue) |
| `section` | 24 |
| `cardRadius` | 20 (today's code mixes 20/22/24; standardize on 20) |
| `thumbRadius` / `thumbSize` | 12 / 56 |
| `minTap` | 44 × 44 for every interactive target |
| Main button | at least 50 pt tall, grows with text |
| Screen inset | 16–20 pt; respect system List/Form margins |

At accessibility text sizes stack metadata and actions vertically, let cards grow and scroll the whole content. On wide layouts center a ~600 pt content column.

## 6. The scene: sky and grass

| Piece | Where |
|---|---|
| `SkyBackground(grassHeight:)` | Full-screen sky + grass: play, countdown, cleared, finished, join lobby, host lobby |
| `GrassHill` / `GrassShape` | Wavy two-tone grass strip |
| `HuntTabHeader` → `SceneHeader` _(rename planned)_ | Sky/grass header with the running goose at the top of each tab |
| `HuntTabBackground` → `TabPageBackground` _(rename planned)_ | Pale-sky list background that keeps the status bar sky blue |

Lists, forms and editors use the canvas; the full sky is for "you are in the game" moments.

## 7. The goose (`GooseView`)

| Mood | Meaning | Used on |
|---|---|---|
| `.running` | On the move: joining, connecting, countdown | Tab headers, host lobby (before the code), countdown |
| `.waiting` | Calm: waiting for something | Clue screen, lobby, host "waiting for players" |
| `.honk` | Something happened | Checkpoint cleared, import sheet, join lobby when the connection drops |
| `.celebrate` | Done! | Hunt finished |

The goose is decorative (`accessibilityHidden`) and draws still under Reduce Motion. The Live Activity uses its own simpler `ActivityGoose` that pushes in when a checkpoint clears.

## 8. Liquid Glass: controls only

Hackathon guidebook rule: **Liquid Glass is for controls** (buttons, toolbars, tab bars, tappable pills), **not for content cards or backgrounds**.

- Let system bars and the tab bar provide their own glass. Don't paint over them or add glass to controls already styled by their container.
- Floating custom controls (End hunt ×, leaderboard, camera Close) use `.buttonStyle(.glass)`. Use `.glassProminent` sparingly; the main action is the solid orange `.gooseProminent()`.
- One glass treatment per control; no glass on glass. Group neighboring glass controls in a `GlassEffectContainer`.
- **Content** (clue card, split times, lobby players, photo placeholders, status labels) uses a solid or tinted rounded card: `.brandCard(.onSky)`, `.brandCard(.tinted)`, or `StatusPill`. Today's `.skyCard()` and five other content views still use glass; the full list and replacements are in `docs/phase0/THEME_MERGE_PLAN.md` §3.
- Respect Reduce Transparency and Increased Contrast. Over live video, glass is never a contrast guarantee: use a dark scrim.

## 9. Components

| Component | Status | Notes |
|---|---|---|
| `.gooseProminent()` | live | Solid orange capsule, ink label, large. One per screen. |
| Secondary button | live | Native `.bordered` (tinted ink or sky) or plain. |
| `.brandCard(_:)` (`.plain`, `.onSky`, `.tinted`) | planned | Replaces `.skyCard`, `QuarryCardRow` and the 8 hand-rolled grouped cards. Solid, radius 20, padding 16, outline under Increased Contrast (from Cody's `QuarryCardRow`). |
| `.brandField()` | planned | Text-field well on the Join form. |
| `StatusPill` | planned | Solid capsule for non-interactive labels (split time, rank, timer). |
| `MetricTile` | planned (from `QuarryMetricView`) | Title + big rounded value + symbol, grows with Dynamic Type. |
| `CheckpointProgressBar` | planned (from `PlayView.progressBar` + `QuarryProgressView`) | Segments for ≤ 12 checkpoints, bar otherwise; on the sky: grass/white/faded, on cards: success/orange/neutral; one spoken label. |
| `HuntThumbnailView` | planned (from `huntThumbnail()`) | Rounded photo or flag placeholder. |
| `HuntRow` | live | Thumbnail, title, checkpoint count, setup warning. |
| `GooseView`, `SkyBackground`, `SceneHeader` | live | See sections 6–7. |
| Empty / error state | live | `ContentUnavailableView` where it fits; explain and offer the existing recovery action; inline errors sit beside the field with text and symbol. |

## 10. Camera (Cody)

Full-screen live preview; only the preview extends under safe areas. Close top-leading as a glass button (≥ 44 pt, labeled). Clue/target label below the top controls, match ring and shutter centered near the bottom with one line of guidance above. White text on a black scrim of at least 65% (80% today; solid with Reduce Transparency). The ring has a dark track; never a thin colored line directly over video. Neutral progress while matching ("Hold steady", "Matching…"); green and "Verified" only after the verified still succeeds. A score is a match indicator, not a probability. Never simulate success.

## 11. Feedback and motion

One success haptic per confirmed checkpoint (`PlayView` triggers on `lastClearedNumber`); don't double-fire with camera feedback. Use 150–250 ms fades or small checkmark emphasis; never gate progression on an animation. Under Reduce Motion remove springs, scaling and travel (the goose stands still).

## 12. Accessibility acceptance (Cody)

Before calling a screen done, check on device:

- Contrast targets above, including Increased Contrast, and white-on-sky text.
- Smallest layout, landscape, and the largest accessibility text size: clues wrap, actions stay reachable, keyboard and safe areas behave natively.
- VoiceOver order: title, clue, progress, action. Icon-only controls have labels; verification is announced once, without timer or score chatter.
- Cleared/current/upcoming states are distinguishable without color; decorative images are hidden; meaningful photos have labels.
- Reduce Motion and Reduce Transparency keep the same actions and information.
- Bright, dark and busy camera scenes keep Close, capture, status and recovery readable.
- Create → host → join → play → verify → advance → finish, and both deep links, still work. A successful build alone doesn't validate an interface.

## 13. History

- **Hackathon (Nov 8, 2026):** Cody's ivory-white + orange `QuarryTheme` system and the original version of this guide, alongside the sky/grass/goose brand in `Quarry/Design/` that most screens ended up using. Both systems shipped in the hackathon build.
- **Phase 0 (now):** one system named for GooseChase; glass only on controls. Migration steps: `docs/phase0/THEME_MERGE_PLAN.md` §4.

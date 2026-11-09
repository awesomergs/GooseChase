# Quarry visual design

## Direction and scope

IVORY WHITE + ORANGE: light, warm, and native to iOS. Ivory backgrounds and warm-white cards provide most of the interface; orange marks actions, selection, and small highlights. The running-goose icon supplies personality alongside rounded headings and brief completion feedback. Keep interface actions in SF Symbols; preserve the existing Icon Composer artwork.

This is a design guide, not an app behavior change. Preserve navigation destinations, persistence, verification thresholds, camera callbacks, session timing, permissions, and the contracts in SPEC.md section 6. This app-wide styling pass is explicitly authorized across the existing screen folders; preserve shared contracts and project settings. No new dependencies or features are required by this guide. The user-approved ivory-white and orange palette below supersedes the older “Accent = indigo” direction in SPEC.md section 4; all other scope and contract rules remain binding.

## Native Apple foundation

Follow [Apple’s Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines). Prefer NavigationStack, native navigation titles and toolbars, List, Form, standard Buttons, system sheets, and full-screen camera presentation. Use TabView only when existing top-level destinations warrant it; the current hunt flow does not need new tabs.

Preserve native back gestures, safe areas, sheet dismissal rules, keyboard avoidance, text editing, and focus behavior. Keep standard toolbar placements and system control geometry. Use real Buttons and NavigationLinks rather than gesture-only substitutes. Destructive actions use the native destructive role. Keep ivory, warm white, and orange primarily in content surfaces and accents.

## Semantic palette

Use QuarryTheme semantic colors with light and dark appearances. The separately compiled widget extension mirrors these values in private ActivityTheme tokens without changing target membership. Hex values are sRGB. The app window always prefers light appearance, per the updated product direction, so ivory surfaces remain visible even when the phone uses Dark Mode. Dark palette tokens remain available for previews and the separately hosted Live Activity; camera overlays retain their dark readable backing. System controls and navigation chrome retain their adaptive system colors.

| Semantic role | Light | Dark | Usage |
|---|---|---|---|
| Canvas | `#FFF9F0` | `#1D1916` | Scrollable content background |
| Card | `#FFFEFB` | `#2B2520` | Hunt cards, clue surfaces, content groups |
| Action / selection | `#C45118` | `#FFAB70` | Primary action fill, selected control, actionable text |
| Subtle orange highlight (`sand` token) | `#FFF0DF` | `#49392C` | Quiet supporting fills and metadata groups |
| Primary text | `#2D2925` | `#FFF9F0` | Titles, clues, field values |
| Secondary text | `#746B63` | `#C2B3A5` | Supporting copy on canvas or card |
| Verified | `#2F6B4F` | `#8EC9A5` | Cleared checkpoints, checkmarks, success labels |
| On action / verified fill | `#FFFEFB` | `#2D2925` | Text and symbols on solid accent fills |

Orange signals an important action or selection; avoid decorative orange borders and large orange backgrounds. Green means verified, never merely a promising camera score. Pair green with a checkmark and “Verified” or “Cleared.” Use primary text on highlights; secondary text is intended for canvas and card surfaces. The highlight fill is decorative, not a sufficient control outline by itself. Errors use semantic system red with an explanatory label and symbol.

Require at least 4.5:1 contrast for normal text, 3:1 for large text, and 3:1 for essential control boundaries and status graphics against adjacent colors. Check actual rendered pairings, including disabled and pressed states, Increased Contrast, and camera overlays. Do not lower text opacity to create hierarchy. Add an adaptive separator or stronger outline where a control depends on its edge to be recognizable; quiet card boundaries need not carry interaction meaning.

## Typography and spacing

Use system text styles, never fixed point sizes for text. Rounded headings add personality without changing native navigation title rendering. Body text and controls use the default system design for readability.

| Role | SwiftUI text style | Treatment |
|---|---|---|
| Native screen title | System navigation title | Let NavigationStack style it |
| Current clue | `.title2` | Rounded, bold, leading aligned, unlimited lines |
| Completion headline | `.largeTitle` | Rounded, bold; wraps naturally |
| Hunt title / section heading | `.headline` | Rounded for custom content headings |
| Body / input / button | `.body` / `.headline` | Default design; clear sentence case |
| Supporting metadata | `.subheadline` | Secondary text; do not shrink to fit |
| Timer / numeric progress | `.body` | Monospaced digits, meaningful spoken label |

For custom headings, use semantic fonts with `.fontDesign(.rounded)`. Keep clue copy visually stronger than timers, metadata, or decoration.

| Layout token | Baseline |
|---|---|
| Spacing scale | 4, 8, 12, 16, 24, 32 pt |
| Custom screen horizontal inset | 20 pt; respect system List/Form margins |
| Card padding | 16 pt; 20 pt for the main clue |
| Related text gap | 8 pt |
| Card-to-card gap | 12 pt |
| Section gap | 24 pt |
| Custom card radius | 20 pt |
| Photo thumbnail radius | 12 pt |
| Primary content button | Minimum 50 pt height, grows with text |
| Any interactive target | At least 44 × 44 pt |

These are baselines, not fixed content heights. Let native Forms, Lists, sheets, and buttons use their system metrics. At accessibility text sizes, stack metadata and actions vertically, let cards grow, and scroll the whole content. Never truncate a clue, cap Dynamic Type, or shrink essential text. On wide layouts, center a readable content column of roughly 600 pt maximum width with flexible outer margins.

## Reusable components

- **Primary button:** one visually dominant action per screen, a standard Button using `.borderedProminent` with the action tint. Full content width on clue and completion screens; use native toolbar sizing in navigation chrome. Verb labels such as “Open camera” and “Done.” Use the on-action color for a custom solid fill, including dark mode.
- **Secondary button:** native bordered or plain treatment, lower emphasis, descriptive label. Keep destructive actions in the native destructive role. Disabled actions retain system disabled styling and a visible explanation of unmet requirements.
- **Content card:** solid card surface, consistent radius and padding, leading-aligned text. Prefer spacing to heavy shadows. Use native inset grouped rows in Lists and Forms rather than nesting custom cards inside them. No glass on content.
- **Progress:** “Checkpoint 2 of 5” plus a segmented indicator where space permits. Completed segments have green checks; current has an orange marker and explicit current state; upcoming segments are neutral. At large sizes or large counts, prioritize the textual count over a cramped segment row.
- **Reference photo:** rounded thumbnail in the editor, accessible label such as “Reference photo 1.” Do not stretch the stored small thumbnail into a full-screen hero. No glass, ornament, or implied interactivity without an existing action.
- **Empty / error state:** native ContentUnavailableView where appropriate, concise explanation, and the relevant existing recovery action. Inline errors sit beside the affected field or camera control, with text as well as color.

## Liquid Glass

Let system navigation bars, toolbars, and tab bars use their default appearance. Do not cover them with opaque custom cream or sand backgrounds, hide their system background to recreate it, or add glass effects to controls already styled by their native container. Brand the content beneath the chrome.

Reserve custom Liquid Glass for floating interactive controls, such as camera close and an existing flash control. Prefer the supported `.glass` button style; use `.glassProminent` sparingly for a floating primary action. Use `glassEffect` only when a custom interactive shape needs it. Confirm SDK and OS availability before implementation: these APIs belong to the iOS 26 generation, matching the documented deployment target. Guard APIs if code is reused on older targets, with standard bordered buttons or solid controls as fallback; do not change the deployment target for styling.

Apply one glass treatment per control. Avoid glass on glass, glass cards, glass clue panels, and glass reference photos. For several neighboring custom glass controls, use GlassEffectContainer as appropriate rather than layering backgrounds. Keep controls visually distinct at rest. See Apple’s [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views).

Respect Reduce Transparency and Increased Contrast. Allow system materials to adapt; for custom camera overlays provide a solid high-contrast fallback when transparency compromises readability. Glass alone is not a guarantee of contrast over arbitrary video.

## Screen layouts

### Hunt list

Top to bottom: native large title “Hunts,” trailing plus toolbar button labeled “Create hunt,” then a native inset grouped List on the canvas color. Each hunt row contains a 56 pt thumbnail, rounded headline title, and secondary checkpoint count; include readiness information when available. Keep the title dominant. At large text sizes place the thumbnail above or beside a flexible text block without clipping the title.

Preserve the current row navigation and Edit/Delete swipe actions. Apply the palette to existing start, host, or join actions only where those actions already exist. Empty list: system empty state, “Your next adventure starts here,” and “Create hunt.” Do not introduce onboarding or a new navigation hierarchy.

### Hunt creation and checkpoint editing

Use the existing pushed Form with native back navigation. Order sections as hunt title, ordered checkpoints, then “Add checkpoint.” Checkpoint rows show their number, clue, thumbnail, and readiness where available. Keep native reorder and delete affordances. Preserve existing save and dismissal behavior; do not invent a Save/Cancel transaction around autosaved fields.

The checkpoint editor uses a multiline clue field, followed by a “Reference photos” section containing up to three thumbnails and the existing photo capture action. Supporting copy: “Try a few angles so the camera can recognize it.” Show processing progress in place and inline recovery text on failure. Existing optional test or location controls remain secondary and appear only when implemented. Keep the focused field and photo action reachable above the keyboard.

### Active clue

Top to bottom: native hunt title and existing toolbar actions; “Checkpoint 2 of 5” and progress; one generously padded clue card; secondary elapsed time; then the prominent “Open camera” button. Example clue: “Find the fountain beside the old oak.” The clue receives the greatest visual emphasis, followed by the camera action. Do not expose a reference photo on this screen unless the existing hunt flow already does so.

Keep the main action near the bottom using safe-area-aware layout with scrollable content. At accessibility sizes or in short landscape windows, let it join the scroll flow so it cannot cover the clue. Existing optional location information and leaderboard access stay subordinate. Preserve camera deep links, session state, and quit behavior.

### Camera verification

Use the existing full-screen live preview. Only the preview extends under safe areas. Place Close at the top leading edge, and flash at the top trailing edge only if already supported. Floating controls have at least 44 pt targets and accessible names. Place a short target/clue label below the top controls and the verification/shutter ring centered near the bottom, with match status and one-line guidance above it.

Use white camera text and symbols against a controlled dark backing. A black scrim at no less than 65% opacity behind ordinary white status text is the starting treatment; verify rendered contrast over pure white, dark, and busy scenes. Use solid dark backing with Reduce Transparency. Floating glass controls use adaptive foregrounds and fall back to solid contrasting controls when needed. Give the ring a dark contrasting track/backing; never rely on a thin colored line directly over video.

Use neutral live progress with “Hold steady” or “Matching…”; switch to green and “Verified” only after the existing verification succeeds. A score is a match indicator, not a guaranteed probability. Preserve current auto/manual capture behavior and thresholds. Show permission, unavailable camera, missing references, and retry states clearly, using only their existing recovery actions. Never simulate success or add a bypass for visual polish.

### Checkpoint completion and hunt completion

Checkpoint completion: show a green checkmark and “Checkpoint cleared,” followed by existing available details, then “Next clue” if the flow already pauses there. If it advances automatically, use a brief inline confirmation without introducing a new stop. Never gate progression on an animation.

Hunt completion: scrollable canvas with a green checkmark, rounded “Hunt complete!” heading, hunt title, and a card containing completed count and total time when available. End with a prominent “Done” button using the current exit action. Existing race standings can follow the summary when a race is active.

Captured-photo grids, split times, and match scores are optional presentation slots only when those values already reach the view. The current camera callback does not supply a photo or score, and the model does not store a captured-photo history. Omit unavailable slots; this guide does not authorize changing contracts or adding persistence. Avoid confetti, reward systems, or new replay/share flows.

## Feedback and accessibility acceptance

On a confirmed checkpoint transition, use one subtle 150–250 ms fade or small checkmark emphasis and one success haptic. Coordinate with existing camera feedback so completion does not fire two success haptics. Trigger feedback from the actual state transition, never repeated camera frames or view appearances. Use existing error feedback sparingly; haptics never replace visible status.

Respect Reduce Motion: remove scaling, spring movement, and travel effects; use a brief fade or immediate state update. Respect Reduce Transparency with opaque readable custom overlays. Keep system settings authoritative.

For visual acceptance, verify:

- Light, dark, and Increased Contrast appearances, with all text and essential controls meeting the contrast targets above.
- The smallest supported layout, landscape, and the largest accessibility text size: clues wrap, actions remain reachable, and keyboard/safe-area behavior remains native.
- VoiceOver order follows title, clue, progress, action; icon-only controls have action labels; verification status is announced once without continuous score or timer chatter.
- Verified/current/upcoming states remain distinguishable without color; decorative images are hidden from accessibility and meaningful photos have labels.
- Reduce Motion and Reduce Transparency preserve the same actions and information.
- Bright, dark, and busy camera scenes leave Close, capture, status, and recovery controls readable.
- Existing create, play, verify, advance, finish, and deep-link behavior remains intact. Design documentation and a successful build alone do not validate an implemented interface.


## Existing screen inventory (November 8, 2026)

| Screen / presentation | Swift file(s) | Treatment |
|---|---|---|
| Home hunt list and empty state | `Quarry/ContentView.swift`, `Hunt/HuntListRow.swift`, `Hunt/HuntThumbnail.swift` | Ivory canvas, warm-white cards, orange actions and soft highlight placeholders |
| Hunt details / creation / editing | `Quarry/Hunt/HuntEditorView.swift` | The existing editor is also the details destination; native Form, warm-white rows |
| Checkpoint editing | `Quarry/Hunt/CheckpointEditorView.swift` | Ivory Form, photo thumbnails, orange add action, readable processing/error text |
| Reference photo picker | `Quarry/Hunt/CameraPicker.swift` | System camera/photo-library UI with orange tint; system-owned surfaces retained |
| Active clue and completed hunt | `Quarry/ContentView.swift` (`PlayView`) | Scrollable ivory canvas, white clue/summary card, orange camera/Done actions, green completion check |
| Camera verification and reference capture | `Quarry/Vision/VerifyCameraView.swift`, `CameraCaptureView.swift` | Live video with dark readable overlays, orange shutter, native glass Close; green only after confirmed verification |
| Camera permission / unavailable / retry | `Quarry/Vision/CameraCaptureView.swift` (`CameraStatusView`) | Dark recovery panel with orange recovery actions and explicit text |
| Nearby host/join testing | `Quarry/Nearby/NearbyDebugView.swift` | Existing DEBUG-only Form and glass launcher; ivory canvas and white rows |
| Race standings and empty state | `Quarry/Race/LeaderboardView.swift` | Ivory List, white rows, soft-orange current-player row, orange first-rank badge, green cleared progress |
| Lock Screen / Watch Smart Stack | `QuarryWidgets/QuarryWidgetsLiveActivity.swift` | Adaptive ivory/charcoal surfaces, orange progress, green success |
| Dynamic Island expanded / compact / minimal | `QuarryWidgets/QuarryWidgetsLiveActivity.swift` | Native black Island surface with dark-palette orange actions and green success |

There is no separate hunt-detail, checkpoint-cleared, production HostLobby/Join, location, or Home Screen widget UI in this checkout. Clearing advances automatically; no new screen or feature is introduced. System alerts, navigation chrome, photo-library surfaces, and the live camera image retain their native appearance.


## Validation notes for this implementation

- Xcode builds passed after the shared palette, screen/Form updates, camera/leaderboard changes, Live Activity styling, and active/completion previews were compiled.
- Calculated sRGB contrast: charcoal on ivory 13.78:1; warm gray on ivory 4.98:1 and warm white 5.17:1; warm white on orange 4.59:1; dark-mode charcoal on light orange 7.77:1. Orange body text on ivory is only 4.42:1: use primary/secondary text for canvas copy, and reserve orange text for warm-white rows or native controls. These calculations do not validate rendered glass, disabled controls, or live video.
- Camera progress uses a solid dark circular backing; white progress and verified green therefore do not sit directly on the light-orange shutter fill. Overlays become opaque with Reduce Transparency. Race motion respects Reduce Motion; clue/results scroll and editor clues wrap.
- Home preview rendering timed out. Simulator installation timed out and retry could not connect; no simulator screenshot or UI hierarchy was available. Rendered layout, dark mode, largest Dynamic Type, Increased Contrast, VoiceOver, bright/busy camera scenes, physical camera verification, multiplayer, and Live Activity/Watch runtime still require device validation. The build and palette calculations are not substitutes for those checks.


## Mockup-inspired hierarchy refinement

Use the provided mockups as a reference for hierarchy and grouping while retaining the ivory/orange palette and light-only app window. The home collection now has an introductory heading, camera-hunt badges, stronger card titles, and explicit Details/Start actions. Hunt details show checkpoint/readiness facts and numbered checkpoint rows; editing is still native and autosaved. The checkpoint editor separates clue writing and reference capture into numbered sections with an informative empty-photo state.

During play, show compact real progress, a prominent clue card, separate cleared/time facts, and a bottom camera action. At accessibility sizes and short landscape heights, the action joins the scroll content. Completion uses a success emblem and the same fact cards. Reuse QuarryMetricView and QuarryProgressView; setup readiness stays distinct from verified hunt progress. No decorative maps, invented distances, hints, photo history, or unsupported race controls are introduced.

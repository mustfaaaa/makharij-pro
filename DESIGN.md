# MakharijPro AI · Design contract

This file is the standing design contract for the Flutter app in `frontend/`. New UI work extends it;
changing a decision means updating this file in the same change. It supersedes the Poppins/gold-fill
theme and refines the "Paper, Ink & Illumination" blueprint (19 Sep 2026) toward the owner's direction.

## Read

A Quran reading and recitation tutor for learners of every level, Android first (web and Windows for
development). Expressive register on Home, Reader, Results, Rattil and onboarding; utility register on
Settings, Progress detail and forms. Dials: variance 5 · motion 4 · density 3 (reading) / 4 (progress).
The #1 action is **recite this passage**.

**Feel:** Mushaf elegance + modern mobile UX + subtle Islamic visual identity + an AI tutor that is
patient and honest. Never a template, a dashboard or a chatbot skin.

## Identity: "Illuminated Parchment"

- **Parchment and ivory** are the ground. **Charcoal** is the ink. **Deep green** is the brand and the
  primary action. **Bronze gold** is illumination only: ayah markers, the surah cartouche, the
  recording ring, hasanah, milestones. Gold never fills a button.
- **Colour inside the Quran text is always information** (a Tajweed rule), never decoration.
- **Imagery** is real photography (see `frontend/assets/images/photos/CREDITS.md`), one photo per
  surface, always contained: an atmospheric header or a banner that fades into the page. Never behind
  Quran text, never tiled, never the same photo on two screens.
- **Pattern**: an 8-point star lattice (`GeometricPattern`) at low opacity in headers, cartouches and
  empty states. It is drawn, so it is sharp at every size and costs no assets.
- **Reciters** appear as Arabic-name calligraphy plates, not photographs.

## Colour tokens (`lib/theme/app_colors.dart`)

| Token | Light | Dark | Role |
|---|---|---|---|
| background | `#F7F2E8` | `#0F1311` | parchment / night |
| surface | `#FFFCF5` | `#151A17` | sheets, raised blocks |
| surfaceAlt | `#EFE8DA` | `#0B0E0C` | sunken: inputs, grouped rows |
| container | `#E6DDCB` | `#1F2622` | selected, tonal buttons |
| raised | `#FFFCF5` | `#242C28` | dock, mini-player (dark: lighter, no shadow) |
| border | `#DDD3C0` | `#2F3833` | hairlines |
| borderStrong | `#857D6E` | `#6C766F` | control outlines (≥3:1) |
| textPrimary | `#1D211F` | `#ECE7DC` | charcoal / ivory ink |
| textSecondary | `#4F5550` | `#B8B4A8` | |
| textMuted | `#626963` | `#959488` | never on container/surfaceAlt |
| primary | `#1E4D3B` | `#8CC4A6` | deep green fill, links, selection |
| textOnPrimary | `#FFFCF5` | `#0D241A` | |
| primarySurface | `#DFEAE1` | `#1E3A2E` | muted emerald wash |
| emerald | `#3F7A61` | `#6FAF8F` | progress fills, non-text accents |
| gold | `#A9823F` | `#CDAA66` | ornament strokes only |
| goldInk | `#7A5A1C` | `#D9BA7C` | bronze text |
| goldWash | `#F2E7CE` | `#2A2517` | marker fill |
| ruleMadd | `#A84E14` | `#E68A4F` | dashed underline |
| ruleGhunnah | `#0F6B63` | `#4FC3B5` | wavy underline (jade, never brand green) |
| ruleShaddah | `#A3284A` | `#EE7F9C` | double underline |
| ruleMakhraj | `#2A5C9E` | `#86B4F0` | dotted underline |
| ruleSkipped | `#626963` | `#959488` | struck through |

All text tokens ≥ 4.5:1 on background and surface in both themes (asserted by
`test/theme_contrast_test.dart`). Dark mode is its own palette: green-black ground, ivory ink,
lighter surfaces for elevation, no shadows.

## Type (bundled in `assets/fonts`, OFL)

- **Figtree** 400/500/600/700: interface text. Tabular figures for timers and counts.
- **Amiri** 400/700: display in both scripts (screen titles, surah names, headlines).
- **Amiri Quran**: Quran text only. Default 28, line-height 2.15, justified RTL. Five sizes 24–44.
- No letter-spaced all-caps eyebrows. Hierarchy comes from size and weight. Headings ≥ 1.1 line-height.

## Shape, space, depth, motion

- Spacing 4 · 8 · 12 · 16 · 20 (gutter) · 24 · 32 · 48. Radius: controls 14, containers 20, sheets 28, pills.
- Flat by default, separated by hairlines and space. One soft shadow for floating chrome (light only).
- Motion: press 120ms, state 180–260ms, sheets 300ms; decelerate in, accelerate out; nothing elastic.
  Everything honours `MediaQuery.disableAnimationsOf`. Platform page transitions (swipe-back works).

## Honesty rules (non-negotiable)

- Every number, streak, name and milestone on screen comes from the backend, Firestore or the
  bundled Quran text. No placeholder statistics, praise text or level badges.
- The live cursor never marks a mistake; unreached words are never scored; results are a count
  ("26 of 29 words matched"), not a grade.
- Waveforms show real microphone level or real playback position, or nothing.
- The backend's word `confidence` is a phoneme-match ratio, not model confidence: never label it so.

## Screen composition (what the eye meets first)

| Screen | Focal point | Then |
|---|---|---|
| Home | photo header with greeting and Hijri date | continue-recitation block → practise / read / listen → progress glance → ayah to reflect on |
| Quran | continue banner | search → surah list |
| Reader | the Quran text on a page | cartouche → dock (range · recite · listen) |
| Recording | the recited words inking in | live level ring + timer in the dock |
| Results | "N of M words matched" | rules to review → marked passage → review list → Try again |
| Rattil | reciter plate + listening card | prompts → composer |
| Progress | streak and Quran map | trend → rules → milestones → history |

## Decisions log

- 2026-09-19 Blueprint "Paper, Ink & Illumination" published.
- 2026-09-19 Owner direction: deep green brand, real photography, stronger identity. Palette moved to
  "Illuminated Parchment"; ghunnah moved to jade to stay distinct from brand green.
- 2026-09-19 Navigation kept as the app has it (Home · Quran · Rattil · Progress · Profile + drawer),
  restyled only. The raised gold disc is replaced by a standard destination.
- 2026-09-19 Playback speeds shown as Slow 0.75× · Normal 1× · Fast 1.25× (Fast is new, UI-only).
- 2026-09-19 Reciters appear as their names in Arabic calligraphy, never photographs (no licensed
  portraits; a likeness of a living person needs consent). With three reciters, all share the width.
- 2026-09-20 A standalone Quran word marks its rule with a drawn shape beneath it (`MarkedWord`), not
  a text underline: Amiri Quran's deep descent puts the underline through whatever follows.
- 2026-09-20 Contact shows the support address with Copy; the old form faked a send and was removed.
  Help answers were rewritten to match the backend (all 6236 ayat; score = unflagged / recited).
- 2026-09-20 "Achievements" is titled "Milestones" and "Bookmarks" is "Saved", to match the entry
  points that lead to them. Route paths are unchanged.
- 2026-09-20 Rattil screen rebuilt around one question. The three reciter plates
  left the page: the reciter is named on a 52dp row above the composer and chosen
  in a sheet. The header photo (Mushaf on green cloth) sits at 30% inside a deep
  green wash, so it reads as material rather than as a picture, and folds to 62dp
  while the conversation is scrolled. Gold bars beside the wordmark and the line
  under it only appear while a Qari is actually sounding.
- 2026-09-22 Launcher icon: the Mushaf's eight-point star in ivory with a gold edge,
  a voice of five bars inside it, on brand green; with an Android 13 monochrome layer.
  Source art in frontend/assets/icons, regenerated by `dart run flutter_launcher_icons`.
- 2026-09-22 Launch: the native splash is the star alone on #0E271F (no icon plate).
  Flutter continues from that exact frame into the makharij sequence: a head in profile
  draws, a point of sound travels from the throat to the lips lighting each makhraj
  with its letters, leaves as rings and becomes the star. Full (~2.6s) once a day,
  short (~0.8s) otherwise, tap to skip, static when animations are off.
- 2026-09-22 Onboarding rebuilt as three cinematic screens sharing one mood
  (shared/ui/cinematic.dart): a licensed photograph laid into deep green, a slow camera
  drift, light beams and dust on one ambient ticker. 1 · Al-Muzzammil 73:4, the ayah
  Rattil is named after; 2 · the Basmala igniting word by word over a wave of light;
  3 · a frosted verdict card flagged, tried and cleared. Quran text comes from the bundled
  asset; the two demonstrations are labelled "An example". Static when animations are off.

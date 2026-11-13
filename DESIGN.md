---
name: "Prodifolio"
description: "Fólio Tipográfico de Oficina — dynamic developer portfolio design system pairing obsidian plates, warm bone proof sheets, 1px architectural hairlines, and custom telemetry."
colors:
  terracotta-accent: "#C86D51"
  terracotta-contrast-dark: "#A14225"
  terracotta-light: "#B34C30"
  terracotta-contrast-light: "#E0896C"
  ochre-secondary: "#D99B52"
  ochre-light: "#915E20"
  chart-teal-dark: "#5A8F8C"
  chart-lavender-dark: "#9387AE"
  chart-oxide-dark: "#B3544B"
  chart-sage-dark: "#7B9B76"
  chart-teal-light: "#336664"
  chart-lavender-light: "#5D5179"
  chart-oxide-light: "#8C362E"
  chart-sage-light: "#496945"
  obsidian-canvas: "#0D0D0E"
  obsidian-surface: "#141416"
  obsidian-surface-alt: "#1B1B1F"
  obsidian-hairline: "#27272A"
  obsidian-contrast-plate: "#121214"
  obsidian-contrast-hairline: "#2A2A2E"
  bone-canvas: "#F5F3EF"
  bone-surface: "#EDE9E0"
  bone-surface-alt: "#E3DEC8"
  bone-hairline: "#D2CCC0"
  bone-contrast-hairline: "#D6D1C7"
  ink-light: "#F8F8F6"
  ink-muted: "#A8A59E"
  ink-muted-bone-light: "#B8B3AA"
  ink-dark: "#161616"
  ink-muted-dark: "#4B4841"
  ink-muted-light: "#4E4A42"
  error-dark: "#E07065"
  error-container-dark: "#331815"
  on-error-container-dark: "#FBE2DF"
  error-light: "#A6281F"
  error-container-light: "#F6DCD9"
  on-error-container-light: "#5D130D"
typography:
  display:
    fontFamily: "BodoniModa, Georgia, serif"
    fontSize: "92px"
    fontWeight: 400
    lineHeight: 0.94
    letterSpacing: "-0.03em"
  headline:
    fontFamily: "BodoniModa, Georgia, serif"
    fontSize: "36px"
    fontWeight: 400
    lineHeight: 1.05
    letterSpacing: "-0.02em"
  title:
    fontFamily: "BodoniModa, Georgia, serif"
    fontSize: "24px"
    fontWeight: 400
    lineHeight: 1.15
    letterSpacing: "-0.02em"
  body:
    fontFamily: "Archivo, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.55
    letterSpacing: "0em"
  label:
    fontFamily: "JetBrainsMono, ui-monospace, monospace"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: 1.35
    letterSpacing: "0.08em"
    fontFeature: "tnum"
rounded:
  sharp: "2px"
  scrollbar: "1px"
spacing:
  xs: "8px"
  sm: "12px"
  md: "20px"
  lg: "28px"
  xl: "44px"
components:
  button-primary:
    backgroundColor: "{colors.bone-canvas}"
    textColor: "{colors.ink-dark}"
    typography: "{typography.body}"
    rounded: "{rounded.sharp}"
    padding: "15px 22px"
  button-outlined:
    backgroundColor: "{colors.obsidian-canvas}"
    textColor: "{colors.ink-light}"
    typography: "{typography.body}"
    rounded: "{rounded.sharp}"
    padding: "15px 20px"
  button-text:
    backgroundColor: "transparent"
    textColor: "{colors.ink-light}"
    typography: "{typography.body}"
    rounded: "{rounded.sharp}"
    padding: "12px 14px"
  chip-filter:
    backgroundColor: "{colors.obsidian-surface}"
    textColor: "{colors.ink-light}"
    typography: "{typography.label}"
    rounded: "{rounded.sharp}"
    padding: "6px 12px"
  chip-filter-selected:
    backgroundColor: "{colors.bone-canvas}"
    textColor: "{colors.ink-dark}"
    typography: "{typography.label}"
    rounded: "{rounded.sharp}"
    padding: "6px 12px"
  input-field:
    backgroundColor: "{colors.obsidian-surface}"
    textColor: "{colors.ink-light}"
    typography: "{typography.body}"
    rounded: "{rounded.sharp}"
    padding: "14px 16px"
  card-surface:
    backgroundColor: "{colors.obsidian-surface}"
    textColor: "{colors.ink-light}"
    rounded: "{rounded.sharp}"
    padding: "20px"
  nav-topbar:
    backgroundColor: "{colors.obsidian-canvas}"
    textColor: "{colors.ink-light}"
    typography: "{typography.label}"
    height: "56px"
    padding: "0 28px"
  nav-rail-desktop:
    backgroundColor: "{colors.obsidian-canvas}"
    textColor: "{colors.ink-light}"
    typography: "{typography.body}"
    width: "252px"
    padding: "32px 24px 24px"
  nav-rail-compact:
    backgroundColor: "{colors.obsidian-canvas}"
    textColor: "{colors.ink-muted}"
    typography: "{typography.label}"
    width: "76px"
    padding: "16px 0"
  nav-bottom-mobile:
    backgroundColor: "{colors.obsidian-canvas}"
    textColor: "{colors.ink-muted}"
    typography: "{typography.body}"
    height: "64px"
  proof-sheet-plate:
    backgroundColor: "{colors.bone-canvas}"
    textColor: "{colors.ink-dark}"
    typography: "{typography.headline}"
    padding: "40px"
  lightbox-dialog:
    backgroundColor: "{colors.obsidian-canvas}"
    textColor: "{colors.ink-light}"
    rounded: "{rounded.sharp}"
    width: "740px"
    padding: "32px"
---

# Design System: Prodifolio

## Overview

**Creative North Star: "Fólio Tipográfico de Oficina"**

`prodifolio` treats a software engineer's live portfolio as a printed typographic proof sheet from an editorial workshop. Instead of floating cards, soft shadows, or decorative chrome, the interface relies on stark polarity inversion between deep obsidian ink grounds and warm bone paper plates, bisected by crisp `1px` architectural hairlines and anchored by monumental serif display typography.

The visual system balances literary presence with immediate operational clarity across Flutter Web and Mobile. The opening view pairs a `92px` display nameplate with an inverted proof sheet indexing live GitHub repositories (`N° 01` through `N° 04`), while catalog, telemetry, trajectory, and contact screens expose searchable project filters, hand-drawn `CustomPainter` visualizations, staggered career milestones, and validated API briefing forms on the exact same `2px`-cornered structural grid.

Confirmed visual rejections include soft neon-glow developer templates, blurred glassmorphism surfaces, pill-shaped badge clouds, drop-shadow elevation ladders, third-party charting bloat, eyebrow kickers above `h1` headings, and synthetic decorative Unicode symbols.

**Key Characteristics:**
- High-contrast dual polarity: Obsidian dark default (`#0D0D0E`) paired with Warm Bone proof plates (`#F5F3EF`), inverting cleanly in Papel Osso light mode (`#F5F3EF` canvas with `#121214` obsidian plates).
- Structural `1px` hairlines (`#27272A` in dark mode, `#D2CCC0` in light mode) replacing shadows and blurs to partition rails, split panels, spec grids, and data rows.
- Three-font editorial hierarchy combining self-hosted `Bodoni Moda` display serifs, `Archivo` grotesque UI copy, and `JetBrains Mono` tabular telemetry and ordinal indices.
- Sharp `2px` workshop geometry across interactive controls, chips, inputs, avatar frames, and modal lightboxes, paired with `7px` square brand marks and rectangular chart primitives.
- Hand-authored `CustomPainter` telemetry (segmented ring donut and animated commit bar chart) honoring `MediaQuery.disableAnimationsOf` and WCAG contrast ratios in both themes.

## Colors

A disciplined dual-polarity palette rooted in obsidian charcoal and unbleached bone paper, punctuated by kiln-fired terracotta and burnished ochre accents tuned per surface polarity.

### Primary
- **Terracotta Accent** (`#C86D51`): Primary brand accent in dark mode (`FolioPalette.dark().accent`, `ColorScheme.primary`), used on active rail borders, the `7px` topbar brand square, timeline milestone anchors, peak commit bars, focus rings, and browser `::selection` (`5.33:1` contrast against `#0D0D0E`).
- **Deep Terracotta Contrast** (`#A14225`): Dark-mode `contrastAccent` applied on inverted Warm Bone proof plates (`#F5F3EF`), lifting contrast from `3.29:1` to `5.71:1` for repo counts and row metadata.
- **Kiln Terracotta** (`#B34C30`): Light-mode primary accent (`FolioPalette.light().accent`), tuned to `4.75:1` against `#F5F3EF` canvas and surfaces.
- **Lifted Terracotta Contrast** (`#E0896C`): Light-mode `contrastAccent` rendered on `#121214` obsidian contrast plates (`7.10:1` contrast), replacing `#B34C30` (`3.56:1`) on dark inverted surfaces.

### Secondary
- **Workshop Ochre** (`#D99B52`): Dark-mode secondary accent (`FolioPalette.dark().accentSecondary`, `8.10:1` on `#0D0D0E`), coloring standard bars in `ActivityChartPainter` and the second slice of `chartPalette`.
- **Burnished Ochre** (`#915E20`): Light-mode secondary accent (`FolioPalette.light().accentSecondary`, `4.95:1` on `#F5F3EF`), used for light-mode commit bars and secondary telemetry slices.
- **Telemetry Chart Accents** (`#5A8F8C`, `#9387AE`, `#B3544B`, `#7B9B76` in dark; `#336664`, `#5D5179`, `#8C362E`, `#496945` in light): Categorical chart swatches in `FolioPalette.chartPalette` for multi-language breakdown bars and `LanguageChartPainter` segments.

### Neutral
- **Obsidian Canvas** (`#0D0D0E`): Default dark scaffold background, top bar, navigation rail, lightbox body, and `index.html` body/`theme-color`/scrollbar track.
- **Obsidian Surface** (`#141416`): Recessed dark containers (`CardThemeData`, contact form card, telemetry panels, commit log box, `AsyncStateView` error cards, `InputDecorationTheme.fillColor`).
- **Obsidian Surface Alt** (`#1B1B1F`): Dark `surfaceAlt` (`primaryContainer`, `surfaceContainerHighest`, avatar fallback frame, mobile `NavigationBar` active indicator).
- **Obsidian Hairline** (`#27272A`): Universal `1px` border, divider, and default scrollbar thumb in dark mode.
- **Obsidian Contrast Plate & Hairline** (`#121214`, `#2A2A2E`): Light-mode `contrastSurface` and `contrastHairline` used on inverted proof sheets, manifesto plates, briefing plates, and modal bottom sheets.
- **Warm Bone Canvas** (`#F5F3EF`): Dark-mode inverted `contrastSurface` proof plate (`16.33:1` against `#161616`) and light-mode default scaffold `canvas` (`16.88:1` against `#121214`).
- **Warm Bone Surface & Alt** (`#EDE9E0`, `#E3DEC8`): Light-mode recessed card/input `surface` and active indicator `surfaceAlt`.
- **Warm Bone Hairlines** (`#D2CCC0`, `#D6D1C7`): `1px` borders on light-mode surfaces (`#D2CCC0`) and dark-mode Warm Bone proof plates (`#D6D1C7`).
- **Paper Ink & Muted Ink (Dark Mode)** (`#F8F8F6`, `#A8A59E`): Primary dark-mode ink (`18.27:1` on `#0D0D0E`) and secondary telemetry ink (`7.90:1` on `#0D0D0E`).
- **Charcoal Ink & Muted Ink** (`#161616`, `#4B4841`, `#4E4A42`, `#B8B3AA`): Primary ink on bone (`#161616`), muted ink on dark-mode proof plates (`#4B4841`, `8.23:1`), muted ink on light-mode canvas (`#4E4A42`, `7.95:1`), and muted ink on light-mode obsidian plates (`#B8B3AA`, `8.97:1`).
- **Semantic Error Tokens** (`#E07065`, `#331815`, `#FBE2DF` in dark; `#A6281F`, `#F6DCD9`, `#5D130D` in light): Reserved strictly for form validation alerts and HTTP/network `AsyncStateView` errors.

### Named Rules
**The Dual-Plate Polarity Rule.** Every primary view anchors its editorial manifesto or catalog index on an inverted `contrastSurface` plate (`#F5F3EF` Warm Bone on `#0D0D0E` Obsidian in dark mode; `#121214` Obsidian on `#F5F3EF` Papel Osso in light mode), establishing focal hierarchy through value inversion rather than drop shadows.

**The Contrast-Safe Accent Rule.** Standard accents (`#C86D51` in dark mode, `#B34C30` in light mode) are permitted only on their native canvas polarity; whenever accent text or telemetry appears on an inverted `contrastSurface` plate, it MUST switch to `contrastAccent` (`#A14225` at `5.71:1` on bone; `#E0896C` at `7.10:1` on obsidian) to preserve WCAG AA legibility.

## Typography

**Display Font:** `Bodoni Moda` (`BodoniModa`, bundled TTF weights `400` and `600`, fallback `Georgia, serif`)
**Body Font:** `Archivo` (`Archivo`, bundled TTF weights `400`, `500`, `600`, fallback `-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`)
**Label/Mono Font:** `JetBrains Mono` (`JetBrainsMono`, bundled TTF weights `400` and `500`, `FontFeature.tabularFigures()`, fallback `ui-monospace, monospace`)

**Character:** Dramatic Didone display contrast (`Bodoni Moda`) commands editorial presence at hero scale (`92px`), balanced by neutral grotesque `Archivo` for dense technical copy and `JetBrains Mono` with tabular numerals for catalog codes (`N° 01`), commit SHAs, and live telemetry.

### Hierarchy
- **Display** (`400`, `92px` desktop hero / `54px` mobile hero / `64px` theme `displayLarge`, `0.94`–`0.96` line-height, `-0.03em` to `-0.025em` letter-spacing): Used exclusively for the hero identity (`Hikari`) on the opening screen.
- **Headline** (`400`, `36px` wide screen headers / `28px` compact screen headers / `40px` theme `headlineLarge` / `38px` lightbox title / `32px` wide proof quote, `1.04`–`1.24` line-height, `-0.02em` letter-spacing): Anchors screen titles (`Catálogo de Projetos`, `Estatísticas do GitHub`, `Sobre & Trajetória`, `Fale comigo`), lightbox headers, and proof-sheet quotes.
- **Title** (`400` `BodoniModa` `24px` `1.15` line-height for `titleLarge` & telemetry chart headings / `22px` timeline milestone titles; paired with `600` `Archivo` `16px` `titleMedium`, `15px` catalog/rail row titles, and `14px` practice notes): Organizes chart panels, catalog entries, and milestone cards.
- **Body** (`400`, `16px` `bodyLarge` `1.55` line-height / `17px` desktop hero bio / `14px` `bodyMedium` `1.5` line-height, constrained to `maxWidth: 480px` in hero bio): Used for author biography, project descriptions, timeline highlights, and form fields.
- **Label** (`400`–`500`, `10px`–`13px` `JetBrainsMono` with `tabularFigures()`, `0.08em` tracking, uppercase for headers and telemetry strips; plus `Archivo` `600` `13px` `0.7px` tracking for primary buttons and `11px` for mobile bottom navigation): Used for `PRODIFOLIO`, `N° 01` ordinals, repo counts, commit SHAs, chart axis ticks (`10px`), and status readouts (`10px`–`11px`).

### Named Rules
**The Tabular Telemetry Rule.** All numerical readouts, ordinal indices (`N° 01`), star counts, percentages, commit dates, and chart axis ticks MUST use `JetBrainsMono` with `FontFeature.tabularFigures()` (`tabular-nums`) so vertically stacked columns and live updates stay strictly aligned.

**The Zero-Kicker Opening Rule.** Primary display titles (`Hikari`, screen headlines, and lightbox project titles) open directly onto the plate without uppercase eyebrow kickers above `h1` or inline decorative Unicode symbols (`★`).

## Layout

The application runs inside a full-viewport architectural frame (`ResponsiveScaffold`) governed by `1px` `hairline` partitions across three breakpoints (`< 600px` mobile, `600–1023px` tablet, `>= 1024px` desktop):

- **Top Bar (`56px` height):** Spans full width with a `1px` bottom `hairline` (`28px` horizontal padding `>= 600px`, `16px` `< 600px`). Houses the `7px` terracotta square + `PRODIFOLIO` trigger on the left, live repo/user status centered (`>= 600px`), and the theme polarity toggle on the right.
- **Desktop Index Rail (`>= 1024px`, `252px` width):** Fixed left column bordered by a `1px` right `hairline` (`padding: 32px 24px 24px`), containing the five numbered tabs (`01`–`05`) and a bottom repository telemetry summary separated by a `1px` top border.
- **Tablet Compact Rail (`600px–1023px`, `76px` width):** Vertical icon rail (`padding: 16px 0`) displaying centered `20px` icons over `10px` mono codes (`01`–`05`) with a `1px` left `accent` indicator on the active route.
- **Mobile Bottom Navigation (`< 600px`, `64px` height):** Top-bordered `1px` hairline `NavigationBar` displaying the five views (`20px` icons, `11px` `Archivo` labels, `2px` `surfaceAlt` active indicator).
- **Screen Splits & Rhythm:**
  - **Home (`>= 860px` wide):** Asymmetric `11:9` horizontal split (`flex: 11` lead column at `44px` padding vs `flex: 9` proof sheet at `40px` padding) separated by a `1px` vertical `hairline` (`minHeight: constraints.maxHeight - 56`), anchored by a `1px` top-bordered bottom ledger strip (`44px` horizontal, `18px` vertical padding). Stacks vertically with `20px` / `22px` padding below `860px`.
  - **Projects (`>= 720px` wide):** Header (`40px` wide / `20px` compact horizontal padding) over a `1px`-separated `ListView`; wide rows dedicate `112px` to the ordinal/date column, expanded width to details, and right-aligned star readout + actions.
  - **Stats (`>= 880px` wide / `< 520px` compact):** Three-cell KPI ledger separated by `1px` vertical dividers (`>= 520px`) or horizontal dividers (`< 520px`), followed by a `1:1` split chart container (`>= 880px`) or stacked container (`< 880px`).
  - **About & Contact:** About splits `5:7` (`>= 860px`, `28px` gap) between manifesto plate and staggered timeline; Contact splits `5:6` (`>= 760px`, `24px` gap) between briefing plate and form card (`40px` horizontal padding `>= 900px`, `20px` below).
- **Spacing Scale:** `xs: 8px`, `sm: 12px`, `md: 20px`, `lg: 28px`, `xl: 44px` (supplemented by `16px`, `24px`, `32px`, `40px` panel paddings).

## Elevation & Depth

`prodifolio` enforces a strict **zero-shadow, zero-blur matte plane** (`elevation: 0`, `scrolledUnderElevation: 0`, `surfaceTintColor: Colors.transparent` across `AppBarTheme`, `CardThemeData`, `NavigationBarThemeData`, `BottomSheetThemeData`, and `Dialog`). Surfaces never float via ambient drop shadows or backdrop frosting. Spatial hierarchy is communicated exclusively through `1px` solid hairlines (`#27272A` / `#D2CCC0`), stepped neutral tones (`canvas` -> `surface` -> `surfaceAlt`), stark `contrastSurface` plate inversions (`#F5F3EF` vs `#0D0D0E`), and a `78%` black modal scrim behind `_ProjectLightboxDialog`.

### Named Rules
**The Zero-Elevation Ink-and-Rule Rule.** Every container, card, top bar, navigation rail, bottom sheet, and dialog MUST remain at `elevation: 0` with zero box shadows at rest, hover, and active states; structural separation is achieved exclusively through `1px` hairline rules or inverted `contrastSurface` plates.

## Shapes

The geometric vocabulary pairs crisp `2px` architectural corners with square and rectangular telemetry primitives:

- **Universal `2px` Sharp Radius (`rounded.sharp`):** Applied uniformly to `CardThemeData`, `ChipThemeData`, `FilledButton`, `OutlinedButton`, `TextButton`, `IconButton`, `InputDecorationTheme`, `NavigationBarThemeData.indicatorShape`, `_PortraitFrame` (`62x62px`, `Clip.antiAlias`), theme toggle button, language badges, `_ProjectLightboxDialog`, `BottomSheetThemeData` (top `2px`), and `AsyncStateView` state containers.
- **Square & Sharp Rectangles (`0px`):** Structural hairline dividers (`1px`), the `7px` brand square, `10px` timeline anchor squares, `8px` legend swatches, `8px`-tall segmented code composition bars (`2px` gap), and `ActivityChartPainter` vertical commit bars (`slotWidth * 0.56`, minimum `4px` width, `2px` empty-day bar) maintain unrounded `0px` corners.
- **Minimal Circles & Scrollbars:** Circular geometry is restricted to the concentric `1px` guide circles and `18px` `StrokeCap.butt` donut ring of `LanguageChartPainter`. Scrollbars use a `6px` thickness with a `1px` end radius (`rounded.scrollbar`).

## Components

### Buttons
Crisp rectangular actions with `2px` corners, zero shadows, and explicit focus borders.
- **Shape:** Sharp rectangular corners (`2px` radius).
- **Primary (`FilledButton`):** Filled with `contrastSurface` (`#F5F3EF` in dark mode, `#121214` in light mode) and `contrastInk` label (`#161616` / `#F5F3EF`), `15px 22px` padding, `Archivo` `13px` `w600` (`0.7px` tracking); flips to `contrastInk` fill with `contrastSurface` label when placed inside an inverted plate (resume sheet or contact receipt).
- **Hover / Focus:** Hover blends `accent` at `8%` alpha (`hoverColor`); keyboard focus activates a `2px` solid `accent` border (`#C86D51` / `#B34C30`).
- **Secondary / Ghost (`OutlinedButton` & `TextButton`):** `OutlinedButton` uses a `1px` `hairline` border (`1.8px` `accent` on focus), `ink` foreground, `15px 20px` padding, `Archivo` `13px` `w500` (`0.5px` tracking). `TextButton` uses borderless padding (`12px 14px`) with a `1.5px` `accent` border on focus. The topbar polarity toggle uses a `1px` `hairline`-bordered `2px`-radius frame (`14px 7px` desktop, `10px 7px` mobile).

### Chips
Monospaced technical filters and tags with binary high-contrast selection states.
- **Style:** `JetBrainsMono` (`12px` in `FilterChip`, `11px` in contact scope chips and project row badges), `2px` radius, `1px` `hairline` border.
- **State:** Unselected `FilterChip` renders on `surface` (`#141416` / `#EDE9E0`) with `ink` text; selected inverts to `contrastSurface` (`#F5F3EF` / `#121214`) with `contrastInk` text and checkmark. Contact briefing scope chips toggle between transparent + `contrastHairline` border and solid `contrastInk` fill + `contrastSurface` text (`12px 8px` padding). Static language badges on project cards use a `1px` `hairline` border (`8px 3px` padding).

### Cards / Containers
Flat recessed surfaces partitioned solely by `1px` hairlines.
- **Corner Style:** Sharp `2px` radius (`CardThemeData`, contact form, telemetry panels, timeline milestone cards, lightbox commit box, `AsyncStateView` error/empty frames).
- **Background:** `surface` (`#141416` / `#EDE9E0`), stepping to `surfaceAlt` (`#1B1B1F` / `#E3DEC8`) for fallback portrait tiles and active mobile nav indicators.
- **Shadow Strategy:** Zero shadows (`elevation: 0`).
- **Border:** `1px` solid `hairline` (`#27272A` / `#D2CCC0`).
- **Internal Padding:** `20px`–`32px` (`20px` timeline cards, `22px`–`32px` contact form and manifesto/briefing plates, `28px` error/empty containers, `16px` commit message box).

### Inputs / Fields
Matte recessed text fields with high-contrast terracotta focus states.
- **Style:** Filled (`surface`: `#141416` / `#EDE9E0`), `1px` `hairline` `OutlineInputBorder` with `2px` radius, `14px` `inkMuted` label/hint, `accent` cursor, and `accent` selection at `35%` alpha.
- **Focus:** Transitions border stroke to `1.5px` `accent` (`#C86D51` / `#B34C30`) with `18%` `accent` focus overlay.
- **Error / Disabled:** Validation (`errorText` from local validators or HTTP 422 `fieldErrors`) paired with an `errorContainer` live-region alert box (`#331815` / `#F6DCD9`) bordered in `error` (`#E07065` / `#A6281F`); disabled while `state.isLoading` is active.

### Navigation
Numbered architectural index (`01`–`05`) adapting across desktop, tablet, and mobile viewports.
- **Style & States:** Desktop (`>= 1024px`) `_EditorialRail` (`252px` wide, `1px` right `hairline`) displays `Archivo` `15px` labels (`w600` `ink` active, `w400` `inkMuted` rest) opposite `11px` `JetBrainsMono` indices (`accent` active, `inkMuted` rest) over a `1px` bottom rule (`accent` active, `hairline` rest), anchored by the repository telemetry footer. Tablet (`600–1023px`) `_CompactRail` (`76px` wide) displays `20px` icons + `10px` mono codes with a `1px` left `accent` bar. Mobile (`< 600px`) uses a `64px` `NavigationBar` with `1px` top `hairline`, `2px`-radius `surfaceAlt` indicator, `accent` active icon, and `11px` `Archivo` labels.

### Signature Components
- **Proof Sheet Plate (`HomeScreen`):** Inverted `contrastSurface` surface (`#F5F3EF` in dark mode, `#121214` in light mode) presenting a `BodoniModa` manifesto quote (`32px` wide / `24px` compact), uppercase mono language list, `ÍNDICE SELECIONADO` ledger header, and interactive `N° 01`–`N° 04` rows (`56px` ordinal column, `Archivo` `15px` `w600` repository name, `contrastAccent` metadata, `15px` `north_east` icon, `1px` `contrastHairline` divider). Enters with a `550ms` `Curves.easeOutCubic` fade + `14px` upward settle (`Duration.zero` when `MediaQuery.disableAnimationsOf` is true).
- **Technical Lightbox (`_ProjectLightboxDialog`):** `740px` max-width modal (`2px` radius, `1px` `hairline`, `78%` black scrim) featuring a `FICHA TÉCNICA · REPOSITÓRIO` header bar, `38px` `BodoniModa` title, `1px` top/bottom bordered `_SpecCell` telemetry strip (`BRANCH`, `ESTRELAS`, `FORKS`, `ÚLTIMO COMMIT`), `8px` segmented code composition bar (`chartPalette` swatches, `2px` gaps), `surface` commit log panel, and `Solicitar projeto similar` handoff into the Contact screen.
- **CustomPainter Telemetry (`LanguageBreakdownChart` & `CommitActivityChart`):** Hand-painted precision graphics animated over `650ms` (`Curves.easeOutCubic`, skipped under `MediaQuery.disableAnimationsOf`). `LanguageChartPainter` frames an `18px` `StrokeCap.butt` segmented ring between concentric `1px` guide circles with centered `28px` `BodoniModa` share and `10px` mono label; `ActivityChartPainter` plots three `1px` horizontal grid lines (`0%`, `50%`, `100%`) with `10px` tabular labels and sharp rectangular commit bars (`accentSecondary` normal, `accent` peak day, `2px` `hairline` zero-day stub).

## Do's and Don'ts

### Do:
- **Do** enforce `2px` sharp corner radii (`BorderRadius.circular(2)`) and `1px` architectural hairlines (`#27272A` in dark mode, `#D2CCC0` in light mode) across containers, buttons, chips, inputs, and dialogs instead of rounded pills or elevation shadows.
- **Do** switch accent foregrounds on inverted `contrastSurface` plates to `contrastAccent` (`#A14225` on `#F5F3EF` Warm Bone; `#E0896C` on `#121214` Obsidian) so accent text maintains `>= 4.5:1` contrast.
- **Do** render all ordinal indices (`N° 01`), counts, commit SHAs, dates, and chart axis ticks in `JetBrainsMono` with `FontFeature.tabularFigures()`.
- **Do** gate all choreographed transitions (`550ms` proof sheet reveal, `650ms` `CustomPainter` telemetry sweeps, `800ms` staggered timeline tiles) behind `MediaQuery.disableAnimationsOf(context)`.
- **Do** wrap interactive controls, `CustomPainter` charts, and error banners in explicit `Semantics` labels and preserve `1.5px`–`2px` `accent` focus outlines for keyboard users.

### Don't:
- **Don't** add `BoxShadow`, `elevation > 0`, `scrolledUnderElevation > 0`, or backdrop blur effects to cards, rails, top bars, sheets, or dialogs.
- **Don't** place uppercase eyebrow kickers above display `h1` headings (`Hikari`, screen headlines, or lightbox titles), nor introduce synthetic decorative Unicode stars (`★`) or UI emojis in headers, badges, or catalog rows (any leading emoji rendered inside `owner.bio` originates solely from external live GitHub profile data and is not part of the UI system).
- **Don't** place unadjusted `accent` (`#C86D51` or `#B34C30`) text over an inverted `contrastSurface` plate, where contrast falls to `3.29:1` / `3.56:1` below WCAG AA.
- **Don't** add third-party charting packages or round chart primitives (`StrokeCap.round`); keep `ActivityChartPainter` bars rectangular (`0px` radius) and `LanguageChartPainter` arcs `StrokeCap.butt`.
- **Don't** invent testimonials, mock counts, or synthetic metrics; render real API states (`loading`, `ApiException`, `empty`) inside `AsyncStateView` using the same `1px`-bordered `2px`-radius grid.

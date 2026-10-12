# Design: the app looks like the website

Researched 2026-10-12 from `inventory_frontend/src/index.css` (tokens: dark 1–66, light 68–123),
its shared components and pages. `W` = `../Scalezzy inventory /inventory_frontend/src`.

## Tokens (exact)

| Token | Light | Dark |
|---|---|---|
| page bg | `#FAFAFA` | `#000000` |
| card | `#FFFFFF` | `#0A0A0A` |
| input / hover | `#F4F4F5` / `#F4F4F5` | `#111111` / `#1A1A1A` |
| border / border-focus | `#0F000000` / `#26000000` | `#14FFFFFF` / `#33FFFFFF` |
| text / secondary / muted | `#18181B` / `#71717A` / `#757580` | `#FFFFFF` / `#A1A1AA` / `#7B7B86` |
| brand (lime, fills only) | `#A6D92B` | `#A6D92B` |
| brand-ink (brand text) | `#164B1E` | `#A6D92B` |
| brand-solid / on-solid (primary) | `#164B1E` / `#FFFFFF` | `#A6D92B` / `#0B2410` |
| gold (highlight only) | `#B48600` | `#E2C171` |
| danger / success / warning | `#B91C1C` / `#047857` / `#B45309` | `#EF4444` / `#10B981` / `#F59E0B` |
| info / purple / neutral | `#1D4ED8` / `#6D28D9` / `#4B5563` | `#3B82F6` / `#8B5CF6` / `#9CA3AF` |
| panel shadow | 0 4 24 −4 `#0F000000` | 0 4 24 −1 `#80000000` |

- Font: **Inter** (the web declares it; metrically close to what web users see). Codes and shelf
  addresses in monospace 700. Money and quantities use tabular figures.
- Weights: 400/500/600, 700 only for page titles. Nothing heavier.
- Type: page title 24/700 (−0.48 tracking), subtitle 14 secondary; card title 16/600 (big 18/600);
  row title 14/600; body 14, secondary lines 13; captions 12; caps labels 11/600 +0.55 uppercase;
  KPI value ~20/600 on phone with 12/500 caps title.
- Radii: 4 tag, 6 input, 8 button/chip/nav indicator, 12 card/dialog/pill, 16 large card and sheet
  top, stadium for the brand CTA. Spacing 4, 6, 8, 10, 12, 16, 20, 24, 32; page padding 16; card
  padding 14–16; list gap 10.
- Borders first (1px `border`), shadow only the faint panel shadow. Motion 200ms
  `cubic-bezier(.16,1,.3,1)`.

## Components

| Web | Flutter |
|---|---|
| Primary button = **ink** (bg text, fg card), radius 8, 13–14/500, min 44h, disabled 50% | `FilledButtonTheme` |
| Brand CTA (login, scan) = brand-solid pill, 54h, 16/700 | `FilledButton` with `StadiumBorder` |
| Secondary = card bg, 1px border, radius 8 | `OutlinedButtonTheme` |
| Danger = solid danger, white text | `FilledButton.styleFrom(bg: danger)` |
| Links = brand-ink 600 | `TextButtonTheme` |
| Input: filled input colour, border, radius 6, label **above** 13/500 secondary | `InputDecorationTheme` (no floating labels) |
| Card / panel: card, 1px border, radius 12 | `CardTheme`, `SurfaceCard` |
| List row: card radius 12, padding 14; title 600, second line 13 secondary, meta 12 muted | every list item |
| Status pill: padding 3×8, radius 12, 12/500, bg = tone @12%, sentence-case label | `StatusPill(label, tone)` |
| Tabs: 2px underline in primary, selected 600 | `TabBarTheme` |
| Filter chips: input bg, border, radius 8; selected = ink bg, card text | `ChipTheme` |
| Confirm modal: radius 12, title 18/600, body 15/1.5 secondary, Cancel + primary/danger | `DialogTheme`, `confirmAction` |
| Sheets: radius 16 top, drag handle border-focus, sticky footer with top border | `BottomSheetTheme` |
| Toast: card bg, 1px border, radius 8, green/red icon, 2s success / 4s error | floating `SnackBar` |
| Loader: three 8px dots + 12/600 caps label | `LoadingView` |
| Skeleton: hover colour blocks, opacity pulse 1.5s | `Skeleton` |
| Load failed: danger triangle, "Could not load {what}.", message, "This is not the same as having none — nothing has been lost.", secondary "Try again" | `ErrorView` |
| Empty: icon 40, title 17/600, text 14 secondary | `EmptyState` |
| Sidebar active = primary text on input bg (neutral, not brand) | `NavigationBar` indicator = input; Scan = brand-solid circle |
| Settings hub: profile block brand @16%, shop logo/initials tile, cards radius 16 | More screen header |

## Status colours (tone; pill text = tone, bg = tone @12%)

- Orders: Draft neutral · Confirmed info · Partly sent warning · Dispatched success · Cancelled danger.
- Payment: Paid success · "₹X due" warning · Refunded neutral · Written off danger.
- Returns: Requested warning · Received info · Inspected purple · Completed success · Turned down danger.
- Purchase orders: Draft neutral · Sent info · Partly received gold · Received success · Cancelled danger.
- Stock counts: Draft neutral · In progress gold · Completed success · Cancelled danger.
- Stock: healthy success · low warning · out danger. Product: Active success, others neutral.
- Shelf tags: shop floor success · back room warning. Audit accuracy ≥95% success else danger.
- Alerts: out of stock / system error danger · online order success · others gold.

## Theme mode

Web defaults to light, remembers the choice, toggles with a sun/moon in the top bar. App: System /
Light / Dark under More → Appearance, default Light, persisted; status bar icons follow brightness.

## Brand

Web `public/logo.png` (wordmark + "inventory"), `public/scaleezy-logo.png` (wordmark),
`favicon.svg` (S mark lime/`#164B1E`). Spelled **Scaleezy**. App chrome always shows Scaleezy;
the shop's own logo/name only in the More/settings profile and on receipts. On dark, put the
wordmark on a white plate (its dark green is unreadable on black).

## Implementation

`AppPalette` `ThemeExtension` (light/dark from the table) + `context.colors`; `ThemeData` per
brightness built from it (ColorScheme primary = brand-solid, secondary = gold, error = danger,
surface = card, outline = border-focus, outlineVariant = border). Screens use `context.colors` and
`Theme.of(context).textTheme` roles — no `AppColors`, no literal font sizes/weights, no `Color(0x…)`.

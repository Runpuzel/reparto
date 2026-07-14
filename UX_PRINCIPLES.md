# Reparto — UI/UX Principles in Practice

The app follows **Nielsen's 8 (of 10) usability heuristics** called out in the
project spec. Here is exactly where each one is implemented in the codebase.

| # | Principle | How Reparto applies it | Where |
|---|-----------|------------------------|-------|
| 1 | **Visibility of system status** | Loading spinners on every async screen (`AsyncView`), button spinners during sign-in/checkout, realtime unread **notification badge**, order **status pills**, "Added to cart" snackbars, payment progress in the WebView. | `core/widgets/common_widgets.dart` (`AsyncView`, `StatusPill`), `student_shell.dart`, `cart_screen.dart` |
| 2 | **Match between system & real world** | Plain language ("Awaiting Approval", "Ready for Pickup"), money formatted as `GH₵`, real campus & MoMo network names (MTN/Telecel/AirtelTigo), familiar shopping metaphors (cart, storefront, checkout). | `constants/app_constants.dart` (`OrderStatus.label`), `utils/formatters.dart` |
| 3 | **User control & freedom** | Back/close buttons everywhere, cancel buttons in dialogs, students can **cancel pending orders**, remove cart items, close the payment WebView, sign out from any role. | `orders_screen.dart`, `payment_service.dart`, profile screens |
| 4 | **Consistency & standards** | One **design system** (`AppTheme`): shared colors, radii, typography (Plus Jakarta + Inter), button/inputs/cards themed once and reused. Material 3 components throughout. | `core/theme/app_theme.dart` |
| 5 | **Error prevention** | Form **validation** before submission (email, password rules, **Ghana Card format `GHA-#########-#`**, phone, MoMo), confirm dialogs before destructive actions (delete product), stock caps the quantity stepper, server-side checks (RLS, stock, approval). | `utils/validators.dart`, `product_form_screen.dart`, `product_detail_screen.dart` |
| 6 | **Recognition rather than recall** | Category **filter chips**, image-rich product cards, pre-filled edit forms, persisted campus context so users never re-enter it, visible labels & helper text on inputs. | `browse_screen.dart`, `product_form_screen.dart` |
| 7 | **Flexibility & efficiency** | Search + category filters, Google one-tap sign-in, quantity steppers, pull-to-refresh on every list, role-based home routing so each user lands where they need to be. | `app_router.dart`, list screens |
| 8 | **Minimalist / aesthetic design** | Clean spacing, a restrained palette, cards over heavy borders, empty states that guide instead of clutter, progressive disclosure (KYC details only shown to admins). | `EmptyState`, `admin_vendors_screen.dart` |

> The two remaining Nielsen heuristics are also partially covered: **"Help users
> recognize/recover from errors"** via friendly error messages
> (`login_screen._friendly`), and **"Help & documentation"** via this repo's
> guides and inline helper text.

## Visual design system

- **Palette**: **UjustBUY teal `#0E6E74`**, logo navy `#072450`,
  warm gold tertiary `#C8973F`, plus semantic success/warning/danger.
- **Type**: Plus Jakarta Sans for headings, Inter for body (via `google_fonts`).
- **Shape**: 10/16/24 px radius scale, soft card borders, pill status badges.
- **Brand**: the app icon is the canonical mark, supported by a teal/navy
  gradient, a restrained auth hero, and a custom-painted Google "G".
- **Light / Dark / System**: full dark theme (`AppTheme.dark`) with a user
  toggle that **persists** via `shared_preferences`
  (`core/theme/theme_provider.dart`, `ThemeModeTile` in every profile + a
  `ThemeToggleButton` in the admin app bar).

## Feature additions tied to UX

- **Shops tab** — browse every shop on campus, open a storefront, see all of a
  shop's products, and buy from that specific shop (`shops_screen.dart`,
  `shop_detail_screen.dart`). *Recognition over recall + user control.*
- **Multiple product images** — swipeable carousel with page dots, tappable
  thumbnails, pinch-to-zoom fullscreen, and a "+N" badge on cards
  (`product_detail_screen.dart`, `product_card.dart`). Vendors manage up to 6
  photos and pick a cover (`multi_image_field.dart`). *Visibility of system
  status + match to the real world.*
- **User-specific notifications** — the badge & list are rebuilt on every auth
  change and filtered by `recipient_id` (DB + RLS), so each user only ever sees
  their own. *Error prevention + consistency.*

## Accessibility touches
- 54px minimum button height (comfortable tap targets).
- Sufficient color contrast on text and semantic colors in both themes.
- Icons paired with text labels in navigation and actions.
- Form fields use labels + helper text rather than placeholder-only.

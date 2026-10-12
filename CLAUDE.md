# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ScaleEzy Inventory: a Flutter mobile client (Android/iOS primarily) for a multi-tenant clothing-shop inventory backend. Light mode only. Money is Indian rupees (`formatRupees` in `lib/core/utils/money.dart`).

## Reference repos — the app is built from these

Both live under `../Scalezzy inventory /` (note the trailing space in the folder name).

**`inventory_backend`** (Express + Prisma + Postgres) is the source of truth. Before adding a mobile feature, read its route + controller + zod validation.
- Routes: `src/routes/api.routes.ts` mounts everything under `/api/v1`. Business routes the app may need: `/products`, `/variants`, `/inventory` (+ `/transactions`, `/alerts`), `/inventory-transfers`, `/stock-counts`, `/shelves`, `/search`, `/catalog`, `/dashboard`, `/reports`, `/daybook`, `/customers`, `/sales-orders`, `/counter-sales`, `/counter-returns`, `/returns`, `/dispatches`, `/suppliers`, `/purchase-orders`, `/reorder`, `/team`, `/roles`. Storefront/Shopify/WhatsApp/campaigns/online-shop/admin routes are web/integration-only.
- Permissions: the full catalogue of `resource:action` keys (labels, groups, `implies`) is `src/config/permissions.ts`. Login/session return the already-expanded list, so the app checks with a plain contains (`AuthUser.can`). Gate on permissions, never role names. 403 bodies carry `requiredPermission`.
- Cost visibility: without `cost:view` the server strips cost fields entirely (absent, not null). Never show or derive cost/margin without it.
- List shapes differ by module: products answer `{data, meta:{page,limit,total,pages}}`, inventory/variants answer `{items, pagination:{...}}`. `limit` max 100. Validation errors are 400 `{message:'Validation failed', errors:[...]}`; write races are 409.
- Schema: `prisma/schema.prisma`. Money is `Decimal(10,2)`, serialised as strings. Status enums (e.g. `SalesOrderStatus`, `PurchaseOrderStatus`, `ProductStatus`) are defined there.
- Copy rules: `docs/ROLES_AND_PLAIN_LANGUAGE_PLAN.md`. Product/inventory screens say **YOU PAY** (cost), **YOU SELL AT** (selling price), **YOUR SHARE %** (margin), **ADD PROFIT** (profit %). Reports keep accounting terms. API field names never change.
- Run locally: `npm run dev` (port 4006, needs `DATABASE_URL` + `JWT_SECRET` from `.env.example`). Then `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4006/api/v1` (Android emulator) or `http://localhost:4006/api/v1` (iOS simulator).

**`inventory_frontend`** (React 19 + Vite + react-query) is the reference for **screens and user flows**. It is the full product: cookie login, `<Guard permission=…>` on every business route, store picker, ~77 routes in `src/App.jsx`, pages in `src/pages/` (sales/, shelves/, inventory/, settings/, …), data calls in `src/hooks/` and `src/services/`. Its UI is English only (only its help center is translated). Brand is lime/deep green with light and dark themes; the app is still slate/amber light-only (open decision).

What the web has and the app lacks, ranked by phone fit, plus open decisions (counter sale is retired on the web; store-selection and branding differ): `docs/web-parity.md`. Request/response details for those features: `docs/backend-api.md`. Both were researched 2026-10-12; re-check the source before building.

## Commands

```bash
flutter pub get
flutter analyze                        # flutter_lints + always_use_package_imports
flutter test                           # all tests
flutter test test/features/shelves/shelf_models_test.dart   # one file
flutter test --plain-name "shelf tree" # one test by name
flutter run                            # default API: the Render deployment
```

Dart SDK `^3.10.1` — the code uses null-aware map elements (`'clientId': ?clientId`).

## Folder structure (feature-first)

```
lib/
  main.dart            bootstrap only: ApiClient.init, session + shop wiring, runApp
  app/                 app.dart (ScaleezyApp), router.dart (go_router: Paths, redirects, routes), app_routes.dart (AppRoutes)
  core/                shared by every feature
    network/           api_client.dart (ApiClient, ApiException, dataOf), api_endpoints.dart (ApiEndpoints)
    session/           auth_session.dart (AuthSession, SessionScope), auth_user.dart (AuthUser)
    shop/              shop_context.dart (ShopContext, ShopScope), shop_repository.dart, shop_models.dart
    models/            cross-feature models (Paged)
    theme/  utils/  widgets/
  features/<feature>/
    data/              <feature>_repository.dart, <feature>_models.dart
    presentation/      screens; presentation/widgets/ for feature-only widgets
test/                  mirrors lib/ (test/core/..., test/features/<feature>/...)
```

Features: auth, shell (bottom nav + More), dashboard, products, inventory, scanner, orders, shelves, customers, suppliers, purchase_orders, team, settings. A new web feature (e.g. returns) gets its own `features/returns/{data,presentation}`.

Rules:
- Imports are always `package:scaleezy/...` (lint-enforced).
- Every backend path goes in `ApiEndpoints`. `test/core/network/api_endpoints_test.dart` pins each path; add a line there for a new one.
- One repository per feature, one method per endpoint, with the required permission in its doc comment. Repositories take an optional `ApiClient` (for tests) and default to `ApiClient.instance`.
- Routing is `go_router`, built in `lib/app/router.dart`. Paths copy the website's (`inventory_frontend/src/App.jsx`) wherever both have the screen; they are constants in `Paths`, and `docs/routing.md` has the table. A new screen gets a route there, guarded by its permission (`_guard` shows `NoAccessScreen` in place, as the web's `<Guard>`).
- Every screen-to-screen move goes through a typed `AppRoutes` method, which calls `context.push<T>(path, extra: …)` so an awaited result comes back and the caller can reload. Objects travel as `extra`; a route that needs one also fetches it by id when it is missing (an address opened directly). `go` is only for tabs, sign-in and the NoAccess way out: it never completes an awaited push. Bottom-tab switching stays in `MainNavigationScreen` (`selectTab`).
- Sheets and dialogs open on the root navigator (`useRootNavigator: true`) so the bottom bar is not live behind them.
- MVVM everywhere: no screen calls a repository or uses `setState` for data (remaining `setState` is purely visual: password visibility, torch, an expanded rack). The pattern, see `features/products/`:
  - The view model lives in `presentation/view_models/<screen>_view_model.dart` and extends `ViewModel` (`core/view_model/view_model.dart`, a `ChangeNotifier` that ignores notifications after dispose). It owns all loading, paging, filters and request guards, takes its repositories as optional constructor arguments, and never imports Flutter widgets.
  - The screen keeps only UI: controllers, dialogs, sheets and navigation. It takes an optional `viewModel` (tests pass one; otherwise it creates and disposes its own), rebuilds through `ListenableBuilder`, and imports no repository or `ApiClient`.
  - Purely visual state (an expanded card, a draft inside a filter sheet) stays in the widget.
  - Tests: `test/features/<feature>/` holds view model unit tests with fake repositories (subclass the repository and pass `ApiClient.withDio(Dio())`; see `products_fakes.dart`) plus one widget test that pumps the screen with a view model built on those fakes.

## Architecture

**No state-management package.** App-wide state is two `ChangeNotifier`s exposed through `InheritedNotifier` scopes, created in `main.dart`:
- `AuthSession` / `SessionScope` — signed-in user and permissions. `SessionScope.of(context).can('resource:action')` gates UI; `'*'` is the owner wildcard. Use `.read(context)` from `initState`/callbacks.
- `ShopContext` / `ShopScope` — branding, store locations, and the selected store. Loaded/cleared by a listener on the session in `main.dart`.

The router's `redirect` (`authRedirect` in `lib/app/router.dart`, refreshed by the session) shows the splash while the session is unknown, `/login?from=<where you were>` when signed out, and after sign-in goes back to `from` or else to `firstLandingPath` (the web's order). A 401 from any call triggers `ApiClient.onUnauthorized` → session expires → back to login, with every pushed screen gone.

**Network:**
- `ApiClient` is a singleton (`ApiClient.init()` / `.instance`) over Dio. Auth is the backend's httpOnly `token` cookie kept in a `PersistCookieJar` (skipped on web). Selected store is sent as the `x-location-id` header (null = all stores). Long timeouts are deliberate (slow remote DB). A 429 interceptor retries up to twice, honouring `Retry-After` ≤ 20s.
- All failures become `ApiException` whose `message` is the server's text, shown to users verbatim (`ErrorView`, `showMessage` in `core/widgets/async_state.dart`). A 200 with `{success: false}` also throws unless `acceptUnsuccessful` is set (login uses this for workspace selection → `WorkspaceChoiceRequired`).
- Responses are inconsistent: most are `{success, data}`, some are raw arrays/objects. Unwrap with `dataOf()`, then coerce with `asMap` / `asMaps` from `core/utils/json_parse.dart`.

**Models** are hand-written `fromJson` factories, no codegen, built on the `as*` helpers in `core/utils/json_parse.dart` (`asMoney`, `asInt`, `asString`, `asOptString`, `asDate` / `asDateOrNow`, `asMaps`, `asHexColor`). They must tolerate server quirks: Prisma decimals arrive as strings, fields may be absent when hidden by permission (e.g. cost), stock is summed across per-location rows. Each feature's `*_models_test.dart` pins these behaviours with real payload shapes; add a case when changing a parser.

**Screens:** `MainNavigationScreen` is the bottom bar around a `StatefulShellRoute.indexedStack` of five tabs (Dashboard, Products, Scan, Orders, More), each with its own back stack; tapping the current tab returns it to its first screen, and back on another tab's first screen goes to Dashboard. Tabs stay alive, so screens that depend on the selected store watch `ShopScope.of(context).revision` and reload when it changes (see `products_screen.dart`, `orders_screen.dart`). `ScannerScreen` takes `active` (the router passes `TickerMode.of`) so the camera (`mobile_scanner`) runs only while its tab is shown. "More" modules are listed in `features/shell/presentation/more_screen.dart` by path, with an optional permission filter.

**UI kit:** colours and theme in `core/theme/app_theme.dart` (`AppColors`, `AppTheme.lightTheme`). Reusable widgets are in `core/widgets/ui.dart` (`PageHeader`, `SurfaceCard`, `SearchField`, `Skeleton`, `Pressable`, `QuantityStepper`, `confirmAction`, …) and `core/widgets/async_state.dart` (`LoadingView`, `ErrorView`, `showMessage`); `core/widgets/no_access_screen.dart` is the page a role cannot open. Contact helpers (`launchContact`, `whatsappNumber`, `avatarColour`) are in `core/utils/contact_utils.dart`. Reuse these rather than styling inline.

User-facing copy is plain language aimed at shop assistants.

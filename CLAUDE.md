# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ScaleEzy Inventory: a Flutter mobile client (Android/iOS primarily) for a multi-tenant clothing-shop inventory backend. Light mode only. Money is Indian rupees (`formatRupees` in `lib/utils/money.dart`).

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

**`inventory_frontend`** (React 19 + Vite + react-query) is a reference for **screens and user flows only**. It is behind the backend: it has no login, permission checks or store selection, and uses `x-client-id` and hard-coded URLs. Do not copy its API/auth patterns or its dark theme. Pages are in `src/pages/` (routes in `src/App.jsx`), and data hooks per resource are in `src/hooks/`.

Web features not yet in the mobile app: create-product wizard, sales-order creation/editing + dispatch, returns, stock counts (audits), inventory ledger, alert center, stock adjustment, variant add/bulk edit, archive/trash/restore, catalog config (sizes/colours/categories), label printing, CSV import/export. Mobile-only (keep): login/session, permission gating, store selection, shelves, team.

## Commands

```bash
flutter pub get
flutter analyze                       # lints: package:flutter_lints/flutter.yaml
flutter test                          # all tests (single file: test/widget_test.dart)
flutter test --plain-name "shelf tree" # one test by name
flutter run                           # default API: the Render deployment
```

Dart SDK `^3.10.1` — the code uses null-aware map elements (`'clientId': ?clientId`).

## Architecture

**No state-management package.** App-wide state is two `ChangeNotifier`s exposed through `InheritedNotifier` scopes, created in `main.dart`:
- `AuthSession` / `SessionScope` (`lib/api/auth_session.dart`) — signed-in user and permissions. `SessionScope.of(context).can('resource:action')` gates UI; `'*'` is the owner wildcard. Use `.read(context)` from `initState`/callbacks.
- `ShopContext` / `ShopScope` (`lib/api/shop_context.dart`) — branding, store locations, and the selected store. Loaded/cleared by a listener on the session in `main.dart`.

`AuthGate` in `main.dart` switches splash / `LoginScreen` / `MainNavigationScreen` on `AuthStatus`. A 401 from any call triggers `ApiClient.onUnauthorized` → session expires → back to login.

**API layer** (`lib/api/`):
- `ApiClient` is a singleton (`ApiClient.init()` / `.instance`) over Dio. Auth is an httpOnly `token` cookie kept in a `PersistCookieJar` (skipped on web). Selected store is sent as the `x-location-id` header (null = all stores). Long timeouts are deliberate (slow remote DB). A 429 interceptor retries up to twice, honouring `Retry-After` ≤ 20s.
- All failures become `ApiException` whose `message` is the server's text, shown to users verbatim (`ErrorView`, `showMessage` in `lib/widgets/async_state.dart`). A 200 with `{success: false}` also throws unless `acceptUnsuccessful` is set (login uses this for workspace selection → `WorkspaceChoiceRequired`).
- Responses are inconsistent: most are `{success, data}`, some are raw arrays/objects. Unwrap with `dataOf()`; repositories coerce with their `_list`/`_map` helpers.
- `ApiRepository` = core endpoints (branding, locations, dashboard, products, variants, scanning, stock, orders). `ModuleRepository` = endpoints behind the "More" tab (shelves, suppliers, purchase orders, customers, team, settings). One method per endpoint, with the required permission noted in its doc comment.

**Models** (`lib/models/inventory_models.dart`, `module_models.dart`) are hand-written `fromJson` factories, no codegen. They must tolerate server quirks: Prisma decimals arrive as strings, fields may be null or hidden by permission (e.g. cost), stock is summed across per-location rows. `test/widget_test.dart` pins these parsing behaviours with real payload shapes — add a case there when changing a parser.

**Screens:** `MainNavigationScreen` is an `IndexedStack` of five tabs (Dashboard, Products, Scan, Orders, More); tabs stay alive, so screens that depend on the selected store watch `ShopScope.of(context).revision` and reload when it changes (see `products_screen.dart`, `orders_screen.dart`). `ScannerScreen` takes `active` so the camera (`mobile_scanner`) runs only while its tab is shown. "More" modules live in `lib/screens/modules/` and are listed in `more_screen.dart` with an optional permission filter.

**UI kit:** colours/theme in `lib/theme/app_theme.dart` (`AppColors`, `AppTheme.lightTheme`); reusable widgets in `lib/widgets/ui.dart` (`PageHeader`, `SurfaceCard`, `SearchField`, `Skeleton`, `Pressable`, `QuantityStepper`, `confirmAction`, …) and `lib/widgets/async_state.dart` (`LoadingView`, `ErrorView`, `showMessage`). Reuse these rather than styling inline.

User-facing copy is plain language aimed at shop assistants.

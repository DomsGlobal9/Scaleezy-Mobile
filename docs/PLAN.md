# Plan: the app does everything the website and backend do

Living plan. The app (this repo) is brought to parity with `inventory_frontend` (screens, flows,
wording) and `inventory_backend` (endpoints, rules, permissions). Detail docs: `web-parity.md`
(gap list + decisions), `backend-api.md`, `routing.md`, `design.md`, `behaviour-parity.md`.

## Rules

- Only this Flutter app changes. The backend and website are read-only references.
- Commits carry no `Co-Authored-By` or other AI attribution line.
- Every screen is built from the website page + backend route/controller/zod schema/service — never
  guessed. Wording comes from the website; money words follow the backend copy rules.
- Nothing is "done" until every button on it passes the checks in **Definition of done**.
- Owner decisions are recorded in `web-parity.md` → Decided; open ones are listed at the end here.

## Upstream sync (do this before every phase)

The plan is synced to these commits. Before starting a phase, compare and update the plan.

| Repo | Local branch | Synced to | Remote `main` seen | Reviewed |
|---|---|---|---|---|
| inventory_backend | rehan-backend `4aec9a6` | `4aec9a6` (2026-10-10) | `cbed286` (+4, 2026-10-12) | yes |
| inventory_frontend | rehan-frontend `a445e60` | `a445e60` (2026-10-10) | `eb8e0f4` (+2, 2026-10-12) | yes |

Reviewed upstream commits (no app work needed): backend `c40d8fe` POS till/service note,
`3c3b369` + `0e05837` WhatsApp platform number, `cbed286` onboarding fields; frontend `f7889e3`
Platform Console WhatsApp, `eb8e0f4` onboarding form. All are desk/admin areas (P10).

Procedure:
1. `git ls-remote origin main` (and `dev`) in both repos — read-only. Compare with the table.
2. If new commits exist, read them (`git log` / `git show` on the commits; fetching needs the
   owner's OK — see open decision D3) and classify each: new screen, changed flow/wording, new or
   changed endpoint/permission/validation, or out of scope.
3. Update this plan: the tracker, the affected phase, `backend-api.md`, `web-parity.md`.
4. If an already-built screen is affected, add a "resync" task to the current phase before new work.
5. Record the new "synced to" commits in the table.

## Definition of done (per screen)

A screen is done when all of this holds, and the tracker row says so:

1. **Flow + wording** match the website page (layout adapted to a phone; deviations listed in the
   phase notes with a reason).
2. **Button matrix**: every button, chip, menu item, swipe and form field is a row in
   `docs/button-matrix.md` with: website equivalent (file:line), backend call (method, path,
   permission, body), what the app does, and the test that proves it. All rows ✓.
3. **Backend contract**: each endpoint used has a repository test pinning method, path, query/body
   (from the zod schema) and response parsing from realistic payloads, including cost fields
   absent without `cost:view` and Decimals as strings.
4. **Edge and worst cases** (view-model + widget tests): loading; empty; failed load + retry;
   403 → no-access; 401 mid-flow → sign-in and back; 404; 409 (conflict / out of stock / already
   done); 400 validation (field errors shown); 429 with Retry-After; 500; timeout; offline; slow
   answer arriving after a newer one; store switch mid-load; double tap on every action; leaving
   with unsaved work; huge lists (1,000+ rows) scroll smoothly; very long names/numbers; zero and
   negative quantities; paise rounding; missing optional fields.
5. **Roles**: tested with Owner, Manager, Shop floor, Stock room and Buyer permission sets (the
   backend's role templates) — hidden vs disabled vs no-access exactly as the website.
6. **Look**: renders in light and dark, at 360 dp width and at 1.3× text size, without overflow.
7. **User journey**: multi-step flows have an `integration_test` journey on the fake API.
8. **Device check**: run on the iOS simulator and an Android emulator (camera, keyboard,
   back/swipe, background/resume); notes in `docs/device-checks.md`.
9. `flutter analyze` clean; full `flutter test` green; merged.

## Phases

### P0 — Verification foundation and audit of what exists
Before new screens, prove the current ones.
- **P0.1 Test kit** (`test/support/`): one fake API (Dio adapter) serving fixtures shaped from the
  backend code; helpers to answer each failure kind (401/403/404/409/400-with-errors/429/500/
  timeout/offline/malformed JSON); session and shop fakes with the five role permission sets.
  Replace the per-feature duplicated fakes with it.
- **P0.2 Journeys** with `integration_test` (Flutter SDK, no new package): sign in → workspace
  choice → landing; scan → stock in; receive a purchase order; stock count start → count → finish;
  pick → send out; move to another store → put away; add customer → duplicate phone; store switch
  mid-load; session expires mid-flow; offline start.
- **P0.3 Button matrix** for every existing screen (≈30): build `docs/button-matrix.md`, check each
  row against the website and backend, fix every mismatch found.
- **P0.4 Device pass** on simulator/emulator for every existing screen; live smoke only with a test
  account or local backend (D4).
- **P0.5 Loose ends from earlier merges**: `ApiException` keeps the raw error body (so 409
  "existing customer" needs no extra lookup); product detail reachable by id from dashboard
  low-stock rows; dashboard tiles open filtered lists once those screens exist; `KpiCard` use.

### P1 — Stock control
- Inventory overview `/inventory?filter=low_stock|dead_stock` (variant stock, average cost with
  `cost:view`, stock in/out/adjust).
- Stock adjustment (`POST /inventory/adjustment`, signed, reasons from `/inventory/metadata`) from
  overview, product detail and scanner.
- Alerts centre `/inventory/alerts` + bell badge on Home: active/resolved, read, read-all, pin.
- Ledger `/inventory/ledger?variantId=`: filters (type, reason, from/to in UTC `Z`), paging, opened
  from product detail and overview.
- Dashboard tiles deep-link into these filtered screens.

### P2 — Order actions
- Order detail: confirm (409 `OUT_OF_STOCK` shown per line), cancel (draft/confirmed; "closed
  short" when part sent), send out / dispatch with shelves (`fromSpots`), draft line add/remove,
  "Take a return" entry. No new sale (retired on the web).

### P3 — Returns
- Returns list `/returns`; return detail `/returns/:id`: receive, inspect (restock/damaged/scrap per
  line), complete, reject; start a return from an order (`POST /returns`).
- Counter return / exchange `/returns/new` — **needs D1** (it refunds money).

### P4 — Products: add and edit
- Add product (website `/add/*` wizard): details, sizes/colours with "You sell at"/"You pay",
  catalogue options, camera photos via signed upload — **needs D2** (photo picker package).
- Edit product overview, variant prices/cost (`cost:manage`, price-impact preview), bulk variant
  update, archive/trash/restore, images (order, cover, delete), per-store settings.

### P5 — Shelf work
- Shelf count `/shelves/count`, fill shelves `/shelves/fill` (open/fill/skip; finish/reopen with
  `shelf:manage`), shelf issues `/shelves/issues` (view; resolve with `shelf:manage`), move-all,
  spot history, rack map (read-only).

### P6 — Buying
- Purchase order create/edit (draft lines, deliver-to), status changes (send/cancel), email to
  supplier, reorder suggestions → draft orders `/inventory/reorder`, supplier detail/create/edit and
  supplier products `/inventory/suppliers/:id`.

### P7 — Customers in depth
- Customer returns and orders links, groups/offers shown, loyalty points adjust (`loyalty:manage`),
  store-credit payout — **needs D1**.

### P8 — Team and settings
- Team: invite, role change, active/suspend, reset password, view password (`team:view_password`);
  roles (view; edit within the platform catalogue); stock locations (`admin:locations`); return
  rules (`return:complete`); catalogue options (`admin:catalog`); help centre links out to the web.

### P9 — Reports and extras
- Day book date range (≤31 days), dashboard charts (stock movement, inventory trend, supplier
  spend, dead stock), global search on Home (`/search`), offers list/detail/status toggle,
  PDFs/printing/sharing — **needs D2**.

### P10 — Out of scope unless asked
Campaigns, rack setup builder, shelf label printing, online shop, Razorpay, connected websites,
Shopify, WhatsApp linking, POS tills, CSV import, platform console, onboarding/signup, try-on and
photo jobs. Re-classify if an upstream change makes one of them phone work.

## Working method (each phase)

1. Upstream sync (above). 2. Research: backend route + controller + zod + service, website page +
hooks, written into the phase as a short spec. 3. Build in parallel per feature folder (separate
worktrees), MVVM, website look, light + dark. 4. Button matrix rows + contract + edge + role +
journey tests. 5. Merge one branch at a time; analyze + full tests after each. 6. Device pass.
7. Update the tracker and the coverage figure. Commits without co-author lines.

## Tracker (website business screens)

Status: ✅ done (definition of done) · 🟡 built, audit pending (P0) · 🟠 partial · ⬜ missing.

| Website route | App | Status | Phase |
|---|---|---|---|
| `/dashboard` | Dashboard | 🟠 tiles + low stock; no charts | P0, P1, P9 |
| `/products` | Products | 🟠 read-only list | P0, P4 |
| `/products/:id` | Product detail | 🟠 read-only | P0, P1, P4 |
| `/add/*`, `/preview` | — | ⬜ | P4 |
| `/orders` | Orders | 🟡 | P0 |
| `/orders/:id` | Order detail | 🟠 no actions | P0, P2 |
| `/orders/:id/receipt` | Receipt | 🟡 (no PDF/print) | P0, P9 |
| `/returns`, `/returns/:id` | — | ⬜ | P3 |
| `/returns/new` | — | ⬜ (D1) | P3 |
| `/inventory` | — | ⬜ | P1 |
| `/inventory/ledger` | — | ⬜ | P1 |
| `/inventory/alerts` | — | ⬜ | P1 |
| `/inventory/audits`, `/:id` | Stock counts | 🟡 | P0 |
| `/inventory/purchase-orders` | Purchase orders | 🟡 | P0 |
| `/inventory/purchase-orders/:id` | PO detail + receive | 🟠 receive only | P0, P6 |
| `/inventory/reorder` | — | ⬜ | P6 |
| `/inventory/suppliers` | Suppliers | 🟠 list only | P0, P6 |
| `/inventory/suppliers/:id` | — | ⬜ | P6 |
| `/inventory/transfers` | Move stock | 🟡 | P0 |
| `/shelves` (where is it) | Find piece + shelves | 🟡 | P0 |
| `/shelves/put-away` | Waiting to shelve | 🟡 | P0 |
| `/shelves/move` | Move sheet | 🟠 no move-all | P0, P5 |
| `/shelves/pick` | Pick orders | 🟡 | P0 |
| `/shelves/count`, `/fill`, `/issues`, `/map` | — | ⬜ | P5 |
| `/shelves/setup`, `/labels` | — | ⬜ out of scope | P10 |
| `/customers` | Customers | 🟡 | P0 |
| `/customers/:id` | Customer detail | 🟠 | P0, P7 |
| `/reports/daybook` | Day book | 🟠 one day | P0, P9 |
| `/offers`, `/offers/:id` | — | ⬜ | P9 |
| `/campaigns` | — | ⬜ out of scope | P10 |
| `/settings` (+ tabs) | Settings, team | 🟠 profile, shop, team list | P0, P8 |
| `/settings/locations` | — | ⬜ | P8 |

App-only screens kept: Scan tab, More, shelf spot, appearance.

## Open decisions (owner)

- **D1 Money out on the phone**: counter return refunds and store-credit payouts move money. The
  earlier decision says the app does not take money; may it pay money back?
- **D2 New packages**: photos for add-product need an image picker (`image_picker`); PDFs,
  printing and native share need `pdf` / `printing` / `share_plus`. Allowed?
- **D3 Upstream fetch**: reading new upstream commits needs `git fetch` in the two repos (updates
  only their remote-tracking refs, never their files or branches) — or the owner pulls. Which?
- **D4 Live testing**: a test account on the deployed backend (passed at run time, never committed)
  or a local backend with a test database, for live smoke tests and the device pass.
- **D5 Deep links** (`inventory.scaleezy.com/orders/:id` opening the app): needs a real
  `applicationId` (now `com.example.scaleezy`) and files on the website domain.

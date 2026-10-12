# Routing: the app mirrors the website's routes

Researched 2026-10-12 from `inventory_frontend/src/App.jsx` and the app. The app uses `go_router`
with paths that copy the web's wherever both have the screen. Web references: `W` =
`../Scalezzy inventory /inventory_frontend/src`.

## Web facts the app follows

- Every business route sits behind a login check; `<Guard permission>` shows NoAccess **in place,
  keeping the URL**, with a button to the first page the person can open (`lib/access.js`
  `firstLandingPath`: `/dashboard`, `/products`, `/orders`, `/inventory`, purchase orders,
  `/customers`, `/returns`, `/settings`).
- Signed out → `/login` remembering where you were; after sign-in you go back there (unless it was
  `/` or `/login`), else to the first page you can open. Unknown path → `/dashboard`.
- Detail pages go "back" to their list (explicit), except PO detail which uses history back.
- `/orders/:id/receipt` renders with no app frame. Modals/drawers are never in the URL.
- The web warns about unsaved work only when switching store (pick, shelf count, move stock).

## App route table

Shell: `StatefulShellRoute.indexedStack`, five branches = the bottom tabs (Dashboard, Products,
Scan, Orders, More); each tab keeps its own back stack; tapping the current tab pops to its root.
Browse/detail screens live in their tab's branch. Task flows holding local work, and screens
reached from more than one tab, are top-level routes on the root navigator (full screen).

| Path | Screen | Permission | Navigator |
|---|---|---|---|
| `/login?from=` | LoginScreen | public | root |
| `/dashboard` | HomeScreen | dashboard:view | Dashboard |
| `/products` | ProductsScreen | product:view | Products |
| `/products/:id` | ProductDetailScreen (extra ProductItem, else fetched by id) | product:view | Products |
| `/scan` | ScannerScreen | — | Scan |
| `/orders` | OrdersScreen | sales_order:view | Orders |
| `/orders/:id` | Order detail page (was a sheet) | sales_order:view | Orders |
| `/orders/:id/receipt` | ReceiptScreen | sales_order:view | root |
| `/more` | MoreScreen | — | More |
| `/shelves` | ShelvesScreen | shelf:view | More |
| `/shelves/pick` | PickOrdersScreen | shelf:putaway | More |
| `/shelves/pick/walk?location=&orders=` | PickWalkScreen (→ bool) | shelf:putaway | root |
| `/shelves/find?q=&location=` | FindPieceScreen (app-only) | shelf:view | root |
| `/shelves/spots/:spotId` | SpotScreen (app-only) | shelf:view | root |
| `/shelves/put-away?location=&spot=` | WaitingToShelveScreen | shelf:putaway | root |
| `/inventory/audits` | StockCountsScreen | stock_count:view | More |
| `/inventory/audits/:id` | StockCountScreen | stock_count:view | More |
| `/inventory/purchase-orders?filter=` | PurchaseOrdersScreen | purchase_order:view | More |
| `/inventory/purchase-orders/:id` | PurchaseOrderScreen (→ bool) | purchase_order:view | More |
| `/inventory/purchase-orders/:id/receive` | ReceiveDeliveryScreen (→ bool) | purchase_order:receive | root |
| `/inventory/suppliers` | SuppliersScreen | supplier:view | More |
| `/inventory/transfers` | TransferScreen | inventory:transfer | root |
| `/customers` | CustomersScreen | customer:view | More |
| `/customers/:id` | CustomerDetailScreen | customer:view | More |
| `/reports/daybook` | DayBookScreen | report:financial | More |
| `/settings` | SettingsScreen | — | More |
| `/settings/team` | TeamScreen | admin:users | More |

## Back behaviour

- Android back on a tab root other than Dashboard → Dashboard tab; on Dashboard → exit.
- Details pop within their tab; a deep-linked detail gets its list underneath.
- Pop results stay: `AppRoutes` keeps typed methods that call `context.push<T>(path, extra:)`;
  screens keep `Navigator.of(context).pop(x)`. Use `go` only for tabs, auth, deep links and the
  NoAccess escape — a `go` never completes an awaited push, which would break "reload on return".
- Product detail and PO detail allow swipe-back (no `PopScope(canPop:false)` just to return a
  result); callers reload unless the result is `false`.
- Confirm before leaving: pick walk with unsent pieces (exists), receive delivery with counted
  lines, transfers with lines. Stock counts save per line, so no guard.
- Sheets and dialogs stay imperative, opened on the root navigator.

## Deep links (not enabled)

Worth it later: `/orders/:id`, `/orders/:id/receipt`, `/products/:id`, `/customers/:id`,
`/inventory/purchase-orders/:id`, `/inventory/audits/:id`, `/reports/daybook` on
`inventory.scaleezy.com`. Needs a real `applicationId` (now `com.example.scaleezy`), an Android
intent filter, iOS associated domains, and files on the web domain — the website is not ours to
change, so this waits.

# Web parity: what the website has that the app does not

Researched 2026-10-12 from `../Scalezzy inventory /inventory_frontend` (322 commits, routes in
`src/App.jsx`, permission guards via `<Guard permission=…>` and `Sidebar.jsx`). Re-check the web
source before building any item; it moves fast. Backend details for each item: `backend-api.md`.

## Already in the app (partial unless noted)

| Area | Missing in the app |
|---|---|
| Login, session, password, name, sign out others | Complete. Workspace picker shows ids only; the web shows shop names |
| Dashboard | Web uses `/reports/dashboard-summary` (report:financial) + charts, dead stock, supplier spend; app uses `/dashboard/summary` |
| Products | Read-only: no create/edit, price or cost edit, photos, archive/trash/restore, import |
| Inventory | Stock in/out only: no `/inventory/adjustment`, no ledger screen with filters |
| Orders | List and detail only: no confirm, cancel, dispatch, receipt, start a return |
| Shelves | Has where-is-it, scan, spot, put-away, move. Missing move-all, pick list, shelf count, fill, issues, map, setup, labels |
| Customers | No loyalty points, store credit, groups, offers, returns |
| Purchase orders | List, detail, receive only: no create, status, email, reorder suggestions |
| Suppliers, team | Lists only |
| Settings | Profile, password, shop name/details only |

## Missing, ranked by how well it suits a phone

**High (shop floor, camera, on the move)**
1. Inventory alerts (`/inventory/alerts`) — read, pin, read-all
2. Stock adjustment (`/inventory/adjustment`)
3. Stock counts / audits (`/stock-counts/*`) with the scanner
4. Order actions: confirm, cancel, dispatch (`/sales-orders/:id/*`, `/dispatches`)
5. Counter return / exchange (`/counter-returns/*`)
6. Returns list + online-return receive / inspect / complete (`/returns/*`)
7. Receipt share (`/counter-sales/:id/receipt`) via WhatsApp / PDF
8. Quick product add with camera photo (`POST /products`, variants/bulk, image upload)
9. Shelf work: pick list, shelf count, fill shelves, shelf issues, move-all
10. Transfers between stores (`/inventory-transfers`; instant, no receive step)
11. Global scan search (`/search?q=`)

**Medium**: ledger screen, customer loyalty / store credit, PO create + reorder drafts, day book
(read-only), supplier detail/edit, team invite/roles, variant price/cost edit, rack map, offers list.

**Low (desk / admin / integrations)**: campaigns, rack setup builder, shelf label printing, stock
locations CRUD, catalogue config, roles, online shop, Razorpay, connected websites, Shopify,
WhatsApp linking, POS tills, CSV import, platform console, help center (link out), signup.

## Decisions needed before building

- **Counter sale (new bill)**: the web removed "New sale" on 2026-10-06; bills are made on the
  separate ScaleEzy POS till (`/pos/v1/*`, connection key, not a user session). `POST /counter-sales`
  returns 410 in production. Do not build a counter sale in the app without the owner's say-so.
- **Store selection**: the web always has a store selected (saved choice, else `MAIN-STORE`, else
  first) and persists it; the app defaults to "all stores" (no `x-location-id`) and does not persist.
- **Branding**: the web has a lime / deep-green brand on zinc neutrals with light + dark themes; the
  app is slate + amber, light only.

## Web conventions the app already matches

Cookie `token` session, `/auth/session` restore, workspace selection, server messages shown as-is,
401 → sign-in, `x-location-id` header, English-only UI (only the web help is translated), merchant
money wording ("You pay", "You sell at"; sentence case).

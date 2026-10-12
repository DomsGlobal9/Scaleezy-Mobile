# Behaviour parity: same product, same behaviour

Researched 2026-10-12 (routing and visual styling are in `routing.md` and `design.md`).
`WEB` = `inventory_frontend/src`, `BE` = `inventory_backend/src`. Fix these in the app only.

## High

1. **Store selection.** Web always has one store: saved id if still valid, else code `MAIN-STORE`,
   else the first; persisted (`contexts/LocationContext.tsx`), sent as `x-location-id` on every
   call. App allows "All stores" (no header), doesn't persist, and shelves/picking keep their own
   picker. Bug: with no header, stock in/out lands in MAIN-STORE (`BE controllers/inventory.controller.ts:74-80`)
   while the scanner shows stock summed over all stores. Fix: drop "All stores", persist the id
   (file under app support dir), set `api.locationId` before the first request, use the global
   store in shelves/picking/find-piece; add "Look in every location" to find-piece like the web.
2. **Tab gating and landing.** Web guards every page and lands on the first page the role can open
   (`lib/access.js`). App only gates Orders; Dashboard errors for roles without `dashboard:view`
   (and `/locations` needs it too). Fix: gate Dashboard (`dashboard:view`), Products and Scan
   (`product:view`); start on the first allowed tab.
3. **Labels.** Web maps statuses and roles to words (`components/sales/labels.jsx`: "Partly sent",
   customer Active/Inactive, `describe()`; roles "Owner"/Title Case). App shows raw values
   ("PARTIALLY DISPATCHED", "SUPER_ADMIN"). Fix: `core/utils/labels.dart` ported from labels.jsx +
   `roleLabel`.
4. **"You pay" = `costPrice`** (hand-entered) on the web; app shows `averageCost`. Fix: parse and show
   `costPrice` as "You pay"; average only as "Average cost" if shown at all.

## Medium

5. No-access: web shows a lock, "Not part of your role" / "You cannot {what}", "Ask whoever manages
   your team…", no retry, no toast on 403. App shows a cloud-off error with "Try again".
6. Empty vs failed: web empty = plain text; failed = "Could not load {what}." + message + "This is
   not the same as having none — nothing has been lost." + Try again. App uses the error view for
   empty lists.
7. Stock out: web starts with no reason and refuses "Choose why these pieces are going out:
   damaged, a sample, or returned to the supplier."; success is green. App pre-selects DAMAGE and the
   success snackbar is red.
8. Phones: web normalises to `+91…` and shows "+91 98480 22338", checks email shape, and on 409
   offers to open the existing customer (`utils/phone.js`, `CustomerModal.jsx`). App: length check only.
9. Scanning: web calls `/search?q=` (exact, case-insensitive, matches product code, skips trashed)
   and opens the match; not found = `Nothing found for "X". Check the barcode or SKU.` App uses
   `/variants/search` (case-sensitive exact, then fuzzy chooser) and says "SKU Match Verified" even
   after a fuzzy pick.
10. Product categories come from `/catalog/config` CATEGORY on the web; hard-coded in the app.
11. Stock words: web "Out of stock", "N in stock", "-2 · oversold"; app "Sold out", "N pcs", and
    negative stock shows green.
12. Dashboard: web uses `/reports/dashboard-summary` (report:financial) with money tiles labelled by
    store; app's "Open Purchase Orders" counts drafts while its PO screen doesn't; no out-of-stock count.
13. "Validation failed": web joins `errors[].message`; app shows only "Validation failed"
    (`core/network/api_client.dart` `_messageOf`).
14. Sign-in copy: "Enter the email address you signed up with.", "That does not look like an email
    address.", "Enter your password.", and the "Forgot your password?" note (ask the owner/manager).
    Workspace picker: the web also shows ids only (backend returns `{clientId}`), so the app matches.
15. Orders list: web shows a payment pill (Paid, Part paid, "₹X due", Refunded, Written off), a
    "Where from" filter and the hint "Order number, phone or name".

## Low

16. Connection error sentences (`WEB lib/api.ts:100-132`). 17. Search debounce 300 ms (250 for
where-is-it). 18. Search hints; PO list defaults to all statuses; suppliers show inactive labelled.
19. Receive success "Received — {receipt number}"; web asks before receiving into a store other
than the PO's. 20. Sign-out confirmation inconsistent in the app (Home signs out at once).
21. Cost box paise rule: "Prices go to the paisa: use at most 2 digits after the point, for example
1499.50." 22. Scanner wording ("Point at the barcode"; pick "pieces" over "units"/"pcs").
23. Home low-stock list should include out-of-stock. 24. Server unreachable at start sends you to
sign-in on both; on a phone prefer "Couldn't reach the server, try again" keeping the session.

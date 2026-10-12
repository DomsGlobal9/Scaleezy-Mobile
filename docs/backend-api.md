# Backend API reference for upcoming features

Researched 2026-10-12 from `../Scalezzy inventory /inventory_backend` (routes in `src/routes`,
zod schemas in `src/validations`, services in `src/services`). Endpoints the app already calls are
in `lib/core/network/api_endpoints.dart`. Confirm against the route + schema before building.

## Rules that apply everywhere

- Base `/api/v1`; tenant comes from the session cookie, never sent. `x-location-id` is honoured only
  for the tenant's own stores; unknown ids are silently ignored.
- 100 requests/min per IP across `/api`. JSON bodies are capped at 100 KB.
- Without `cost:view` these keys are **deleted** (not nulled) at any depth: `costPrice, averageCost,
  lastPurchaseCost, inventoryValue, totalValue, unitCost, totalCost, grossProfit, costOfGoods,
  marginPercent, profitPercent` (+ `*Minor`, `previous/newAverageCost`). Keep them optional in models.
- Prisma Decimals arrive as strings (`"1499.00"`); hand-built DTOs (`/inventory/variants`, counter
  returns, dead stock, selling search `price`) send numbers. `asMoney` handles both.
- Envelopes differ: `{success,data}` (inventory, alerts, stock counts, catalog, products, counter
  returns); `{success,total,data,page,limit}` (ledger); `{success,data,meta}` (product list); raw
  object/array (sales orders, dispatches); `{data}` (`/returns`).
- Errors: `{success:false,message}`; zod → 400 `{message:'Validation failed', errors}`; some add
  `details:{code:'OUT_OF_STOCK', variantId, available}`; write races → 409.

## Enums (`prisma/schema.prisma`)

- SalesOrderStatus: DRAFT → CONFIRMED | CANCELLED; CONFIRMED → CANCELLED | PARTIALLY_DISPATCHED |
  DISPATCHED; PARTIALLY_DISPATCHED → DISPATCHED. Invalid transition → 409.
- PaymentMethod: CASH, UPI, CARD, POINTS, CREDIT, ONLINE, BANK_TRANSFER, CHEQUE
- ReturnStatus: REQUESTED, RECEIVED, INSPECTED, COMPLETED, REJECTED; ReturnDisposition: PENDING,
  RESTOCK, DAMAGED, SCRAP; ReturnReason: DAMAGED_IN_TRANSIT, WRONG_ITEM, SIZE_ISSUE,
  CUSTOMER_REJECTED, DEFECTIVE, OTHER
- StockCountStatus: DRAFT, IN_PROGRESS, COMPLETED, CANCELLED
- TransactionType: IN, OUT, ADJUSTMENT. InventoryReason: PURCHASE, SALE, DAMAGE, RETURN,
  CUSTOMER_RETURN, ADJUSTMENT, RETURN_TO_VENDOR, SAMPLE, MANUAL_ADJUSTMENT, TRANSFER, AUDIT,
  INITIAL_STOCK, SUPPLIER_DELIVERY, MANUAL_CORRECTION, AUDIT_CORRECTION, PURCHASE_RECEIPT, SHELF_MOVE
- InventoryAlertType (string; tolerate unknown): LOW_STOCK, OUT_OF_STOCK, OVERSTOCK,
  REORDER_REQUIRED, STOCK_DISCREPANCY, SYSTEM_ERROR, ONLINE_ORDER. Severity: INFO, WARNING, CRITICAL
- ProductCategory: WOMEN, MEN, KIDS, UNISEX. ProductType: READY_TO_WEAR, CUSTOM, UNSTITCHED.
  ProductStatus: DRAFT, ACTIVE, ARCHIVED, TRASHED, OUT_OF_STOCK

## Alerts — `inventory:view`

- `GET /inventory/alerts?status=active|resolved|all&locationId=` → `{data:{alerts[], unreadCount}}`.
  Alert: `id, type, severity, title, message, variantId, productId, productTitle, sku, colorName,
  size, currentQuantity, threshold, locationId, locationName, isRead, isResolved, isPinned,
  createdAt`. Pinned first, then severity. No paging.
- `PATCH /inventory/alerts/read-all` `{locationId?}`; `PATCH /inventory/alerts/:id/read`;
  `PATCH /inventory/alerts/:id/pin` → `{data:{isPinned}}`. (The web calls DELETE; no such route.)

## Ledger — `inventory:view`

- `GET /inventory/transactions?productId&variantId&type&reason&from&to&page&limit(≤100)` →
  `{success,total,data[],page,limit}` (no `pages`). `from`/`to` must be UTC ISO with `Z`.
  Not store-scoped. SHELF_MOVE rows only when `reason=SHELF_MOVE`.
- `GET /inventory/metadata` → `{data:{inventoryReasons, transactionTypes}}` for filter pickers.

## Stock adjustment — `inventory:adjust`

- `POST /inventory/adjustment` `{variantId, quantity (signed, ≠0), reason? (any InventoryReason
  but SALE; default MANUAL_ADJUSTMENT), notes?, locationId?}` → `{data:{quantity, globalQuantity,
  averageCost*, shelves}}`. Cannot go below 0 (400) or into held stock (409). No idempotency key.
- (Existing) stock-out accepts only DAMAGE, RETURN_TO_VENDOR, SAMPLE.

## Stock counts — all `{success,data}`

- `GET /stock-counts` (stock_count:view): every count, newest first, with `_count.items`.
- `POST /stock-counts` (stock_count:create) `{name, locationId?, categoryId?: ProductCategory}` →
  DRAFT with every variant snapshotted as `expectedQty`.
- `GET /stock-counts/:id`: count + `items[{id, variantId, sku, variantCode, barcode, expectedQty,
  countedQty|null, variant:{product:{title}, quantity}}]`; count has `accuracy` (Decimal string).
- `POST /stock-counts/:id/start` (stock_count:create): DRAFT → IN_PROGRESS.
- `PUT /stock-counts/:id/items/:itemId` (stock_count:update) `{countedQty: int ≥0 | null}`.
- `POST /stock-counts/:id/complete` (stock_count:complete): posts AUDIT_CORRECTION adjustments for
  counted lines; uncounted lines untouched. `POST /:id/cancel`: owner only.
- No scan endpoint: match scanned codes client-side on `barcode`, `sku`, `variantCode`.

## Sales orders — raw objects, no envelope

- `GET /sales-orders/:id` (sales_order:view): items with `fulfilledQty`, payments, location.
  Dispatches are not included.
- `POST /sales-orders/:id/confirm` (sales_order:confirm): reserves stock; short stock → 409
  `details.code OUT_OF_STOCK`.
- `POST /sales-orders/:id/cancel` (sales_order:cancel): DRAFT/CONFIRMED → CANCELLED;
  PARTIALLY_DISPATCHED → DISPATCHED (closed short).
- Draft editing: `POST /sales-orders` `{customerId, locationId?}`, `POST /:id/items`
  `{variantId, quantity}`, `DELETE /:id/items/:itemId` (no quantity edit), `PATCH /:id`
  `{discountAmount?, taxAmount?, shippingAmount?}`.
- No endpoint records a payment against an order from a user session.

## Dispatch — `dispatch:create`

- `POST /dispatches` `{salesOrderId, items:[{salesOrderItemId, quantity, fromSpots?:[{spotId,
  quantity}]}]}`; order must be CONFIRMED / PARTIALLY_DISPATCHED. Posts OUT/SALE. No list/GET.

## Returns (parcel flow) — `{data}` envelope

- `GET /returns`, `GET /returns/:id` (return:view).
- `POST /returns` (return:create) `{salesOrderId, reason?, items:[{dispatchItemId, quantity,
  reason?}], notes?}`.
- `POST /:id/receive` (return:receive), `POST /:id/inspect` (return:inspect)
  `{itemsDisposition:[{salesReturnItemId, disposition RESTOCK|DAMAGED|SCRAP}]}`,
  `POST /:id/complete` / `POST /:id/reject` (return:complete). Money is refunded separately.

## Counter returns — `{success,data}`; caller needs `return:counter` (or create + complete)

- `GET /counter-returns/find?q=` (≥2 chars: bill no., phone, name) → ≤15 sales.
- `GET /counter-returns/sale/:orderId` → lines with `dispatchItemId, sold, returned, canReturn,
  paidEach`, customer credit/points, return window.
- `POST /counter-returns/preview` `{orderId, lines:[{dispatchItemId, quantity}]}` → money, credit,
  points, `needsManager`.
- `POST /counter-returns` `{key: uuid (idempotency), orderId, locationId?, lines:[{dispatchItemId,
  quantity, condition RESTOCK|DAMAGED}], reason, note?, refund?:{method CASH|UPI|CARD|CREDIT|ONLINE,
  reference?}, exchange?}`. Never put a card number in `reference`.

## Catalog config — `product:view`

- `GET /catalog/config` → `{data:{SIZE|COLOR|DRESS_TYPE|MATERIAL|DESIGN_TYPE|PRODUCT_TYPE|CATEGORY:
  [{value, label, metadata, sortOrder}]}}`; COLOR metadata `{hex, shades}`.

## Product create — `product:create` / `product:update`

- `POST /products` `{title, category, productType, basePrice (>0 unless DRAFT), description?,
  fabric?, dressType?, brand?, hsnCode?, taxRateBps?, isService?, status?}`.
- `POST /products/:id/variants/bulk` `{variants:[{sku, size?, colorName?, hexCode?, quantity,
  reorderLevel, sellingPrice?, costPrice?}], locationId?}` → `{created, skipped, errors}`.
- Images (not base64): `POST /products/:id/images/upload-url {fileName}` → `{signedUrl, publicUrl,
  storagePath}`; `PUT signedUrl` with the bytes (Supabase, not the API); then
  `POST /products/:id/images {url: publicUrl, storagePath, imageType COVER|GALLERY, isPrimary}`.

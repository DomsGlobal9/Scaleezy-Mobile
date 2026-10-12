# Test kit

Shared helpers for every test. Import them relatively (`import '../../support/fake_api.dart';`).
`fake_api_test.dart` and `kit_test.dart` here show each helper in use.

## Fake API — `fake_api.dart`

A fake backend in Dio's adapter: no network, no package. Routes by method + path (+ query),
records every request, answers JSON or a failure.

```dart
final api = FakeApi()
  ..get('/products', productListJson([productJson('p1')]))
  ..get('/products/:id', (FakeRequest r) => ok(productJson(r.path.split('/').last)))
  ..get('/products', productListJson([]), query: {'category': 'MEN'})
  ..post('/inventory/stock-in', forbidden('inventory:receive'));
final repo = ProductRepository(api.client);        // a repository on it
api.install();                                     // or: ApiClient.instance for the test
```

- The last matching route wins (override a default later in the test). `:name` matches one
  segment; `query` entries must match, others are ignored.
- An answer is plain JSON (a 200), a `FakeAnswer`, a `FakeHandler` `(FakeRequest r) => …`, or a
  `Future` of any of these. `FakeApi(fallback: offline())` answers everything not routed;
  without a fallback such a request is a 404 `FakeApi has no answer for GET /x` and is listed
  in `api.unanswered`.
- Read what was sent: `api.requests`, `api.sent('POST', '/dispatches')`, `api.log`
  (`['GET /products?page=2', …]`). Each `FakeRequest` has `method`, `path`, `query` (strings, as
  the server reads them), `headers`, `locationId` (the `x-location-id` header) and `body`.
- `offlineClient()`: a client for repository fakes that override every call; anything that slips
  through fails as offline.

### Failures, shaped as the backend sends them

| Helper | Answer |
|---|---|
| `unauthorized([message])` | 401 `{success:false,message}`; the session signs out |
| `forbidden('inventory:receive', message: …)` | 403 with `requiredPermission` |
| `notFound([message])` | 404 |
| `conflict(message, code: 'OUT_OF_STOCK', details: {...}, fields: {...})` | 409; `code`/`details` in `details`, `fields` at the top (`phoneTakenFields('c1')`) |
| `validationFailed(['Phone must be 10 digits'], paths: ['phone'])` | 400 `Validation failed` + `errors` |
| `tooManyRequests(retryAfter: 5)` | 429 with `Retry-After` (the test client does not retry) |
| `serverError([message])` | 500 |
| `timeout()` / `offline()` | receive timeout / connection error, no response |
| `malformedJson()` | 200 with a cut-off body |
| `delayed(duration, answer)` | lands after `tester.pump(duration)` |
| `inTurn([a, b])` | `a` to the first call, `b` to every later one |

A stale answer: `final slow = Completer<Object?>(); api.get('/x', inTurn([slow.future, ok(…)]));`
then complete `slow` after the newer request has landed. Wait for real events (a Completer, a
listener, `pumpAndSettle`), never a guessed delay.

`ApiException.body` holds the whole error body, `details` its `details`.

## Fixtures — `fixtures.dart`

Payload builders shaped from the backend (each names its route), e.g. `productJson`,
`productListJson` (`{data, meta}`), `variantJson(cost: false)`, `stockRow`, `itemsPage`
(`{data:{items,pagination}}`), `transactionJson`/`transactionsJson`, `alertJson`/`alertsJson`,
`orderJson`/`orderDetailJson`/`paymentJson` (raw, no envelope), `receiptJson`, `customerJson`,
`phoneTakenFields`, `supplierJson`, `purchaseOrderJson`/`poLineJson`/`receiveAnswerJson`,
`shelfTreeJson`/`spotJson`/`spotContentsJson`/`findJson`/`notShelvedJson`, `pickOrdersJson`/
`pickListJson`/`dispatchJson`, `transferJson`, `countJson`/`lineJson`/`countDetailJson`,
`memberJson`, `dayBookJson`, `brandingJson`, `locationsJson` (MAIN-STORE, a branch, ONLINE, an
inactive one), `userJson`/`loginJson`/`workspaceChoiceJson`/`sessionJson`.
Wrap data in `ok(...)` where the route answers `{success, data}`.

Decimals are strings (`'1499.00'`). Cost: pass `cost: false`, or `withoutCost(json)`, for a role
without `cost:view` — the fields are absent, never null.

## Roles, session, shop — `roles.dart`

- `Roles.owner` (`*`), `Roles.manager`, `Roles.shopFloor`, `Roles.stockRoom`, `Roles.buyer`, and
  `Roles.all` (name → set) to loop over. Expanded keys from the backend's
  `services/role-management/templates.ts` through `config/permissions.ts`.
- `userWith(perms)` → `AuthUser`. `TestSession.as(Roles.buyer)` / `TestSession(user)` /
  `TestSession(null)` (signed out). `become(status, permissions:, onPurpose:)` moves it;
  given `api: fake.client`, a 401 signs it out like the real one.
- `TestShop(stores:, selected:, branding:, api:)`: default stores `defaultStores()`, MAIN-STORE
  selected and sent as `x-location-id` on `api`. `selectLocation` bumps `revision`; `loads`
  counts `load()`. `store('L1', type: 'ONLINE')` builds one store.

## Pumping — `pump.dart`

- `pumpScreen(tester, screen, session:, shop:, theme: ThemeMode.dark, width: 360,
  height: 800, textScale: 1.3, routes: [...], settle: true)`: the screen inside SessionScope,
  ShopScope, ThemeModeScope and a router. A push to a path not in `routes` opens
  `Opened <path>`, so `expect(find.text('Opened /products/p1'), findsOneWidget)` checks where a
  tap went.
- `pumpApp(tester, api:, session:, shop:, at: '/customers')`: the real app and router on the
  fake API (installed as `ApiClient.instance`).
- `testLooks('draws', (tester, look) async { … look.theme … look.textScale … })`: one test per
  light/dark × 1.0/1.3.
- `setPhone(tester, width:, height:, textScale:)`; `expectClean(tester)` (no overflow or
  exception so far).

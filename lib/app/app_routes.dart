import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:scaleezy/app/router.dart';
import 'package:scaleezy/features/customers/data/customer_models.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_models.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';

/// Every move from one screen to another, typed, so a screen never builds a path itself.
/// Pushes (not `go`) so an awaited result comes back and the caller can reload; objects ride
/// as `extra`, and each route can fetch them by id without it. Bottom tabs switch in
/// MainNavigationScreen.
abstract final class AppRoutes {
  /// [path] with the given query values, leaving out the empty ones.
  static String _at(String path, Map<String, String?> query) {
    final q = {
      for (final e in query.entries)
        if (e.value?.isNotEmpty ?? false) e.key: e.value!,
    };
    return Uri(path: path, queryParameters: q.isEmpty ? null : q).toString();
  }

  /// A module on the More tab, by its path.
  static Future<void> open(BuildContext context, String path) =>
      context.push<void>(path);

  /// Pops `true` when stock changed; null after a swipe back, so reload unless `false`.
  static Future<bool?> productDetail(
    BuildContext context,
    ProductItem product,
  ) => context.push<bool>(Paths.product(product.id), extra: product);

  /// A product known only by its id (a dashboard low-stock row); the route fetches it.
  static Future<bool?> productById(BuildContext context, String productId) =>
      context.push<bool>(Paths.product(productId));

  static Future<void> spot(BuildContext context, String spotId) =>
      context.push<void>(Paths.spot(spotId));

  /// Searches the selected store (or every location, by choice on the screen).
  static Future<void> findPiece(BuildContext context, {String? initialQuery}) =>
      context.push<void>(_at(Paths.findPiece, {'q': initialQuery}));

  /// Put away in [locationId], else the selected store. The store's name comes from the shop
  /// (or from [target]).
  static Future<void> waitingToShelve(
    BuildContext context, {
    String? locationId,
    SpotContents? target,
  }) => context.push<void>(
    _at(Paths.putAway, {'location': locationId, 'spot': target?.spotId}),
    extra: target,
  );

  static Future<void> customerDetail(BuildContext context, Customer customer) =>
      context.push<void>(Paths.customer(customer.id), extra: customer);

  /// Pops `true` when the order changed; null after a swipe back, so reload unless `false`.
  static Future<bool?> purchaseOrder(BuildContext context, String poId) =>
      context.push<bool>(Paths.purchaseOrder(poId));

  /// The purchase orders tab of More, e.g. `filter: 'open'` from the dashboard.
  static void purchaseOrders(BuildContext context, {String? filter}) =>
      context.go(_at(Paths.purchaseOrders, {'filter': filter}));

  /// Pops `true` when a delivery was received.
  static Future<bool?> receiveDelivery(
    BuildContext context,
    PurchaseOrderDetail po,
  ) => context.push<bool>(Paths.receiveDelivery(po.summary.id), extra: po);

  /// Orders waiting to go out from the selected store, to pick together.
  static Future<void> pickOrders(BuildContext context) =>
      context.push<void>(Paths.pickOrders);

  /// One walk in the selected store. Pops `true` when something was sent out.
  static Future<bool?> pickWalk(
    BuildContext context, {
    required List<String> orderIds,
  }) => context.push<bool>(_at(Paths.pickWalk, {'orders': orderIds.join(',')}));

  /// Move pieces from one store to another.
  static Future<void> moveStock(BuildContext context) =>
      context.push<void>(Paths.transfers);

  static Future<void> stockCount(BuildContext context, String countId) =>
      context.push<void>(Paths.stockCount(countId));

  static Future<void> orderDetail(BuildContext context, String orderId) =>
      context.push<void>(Paths.order(orderId));

  /// A counter bill's receipt, from the order it belongs to.
  static Future<void> receipt(BuildContext context, String orderId) =>
      context.push<void>(Paths.receipt(orderId));
}

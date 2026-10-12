import 'package:flutter/material.dart';
import 'package:scaleezy/core/shop/shop_models.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/shelves/data/shelf_models.dart';
import 'package:scaleezy/features/customers/data/customer_models.dart';
import 'package:scaleezy/features/purchase_orders/data/purchase_order_models.dart';
import 'package:scaleezy/features/products/presentation/product_detail_screen.dart';
import 'package:scaleezy/features/shelves/presentation/shelves_screen.dart';
import 'package:scaleezy/features/customers/presentation/customers_screen.dart';
import 'package:scaleezy/features/purchase_orders/presentation/purchase_orders_screen.dart';
import 'package:scaleezy/features/picking/presentation/picking_screen.dart';
import 'package:scaleezy/features/transfers/presentation/transfer_screen.dart';
import 'package:scaleezy/features/stock_counts/presentation/stock_counts_screen.dart';
import 'package:scaleezy/features/orders/presentation/receipt_screen.dart';

/// Every push from one screen to another, typed, so a screen never builds a route itself.
/// Switching bottom tabs stays in MainNavigationScreen.
abstract final class AppRoutes {
  static Future<T?> _push<T>(BuildContext context, Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

  static Future<void> open(BuildContext context, Widget page) =>
      _push<Object?>(context, page);

  /// Pops `true` when stock changed.
  static Future<bool?> productDetail(
    BuildContext context,
    ProductItem product,
  ) => _push<bool>(context, ProductDetailScreen(product: product));

  static Future<void> spot(BuildContext context, String spotId) =>
      _push<Object?>(context, SpotScreen(spotId: spotId));

  static Future<void> findPiece(
    BuildContext context, {
    String? locationId,
    String? initialQuery,
  }) => _push<Object?>(
    context,
    FindPieceScreen(locationId: locationId, initialQuery: initialQuery),
  );

  static Future<void> waitingToShelve(
    BuildContext context, {
    required String locationId,
    required String locationName,
    SpotContents? target,
  }) => _push<Object?>(
    context,
    WaitingToShelveScreen(
      locationId: locationId,
      locationName: locationName,
      target: target,
    ),
  );

  static Future<void> customerDetail(BuildContext context, Customer customer) =>
      _push<Object?>(
        context,
        CustomerDetailScreen(customerId: customer.id, preview: customer),
      );

  /// Pops `true` when the order changed.
  static Future<bool?> purchaseOrder(BuildContext context, String poId) =>
      _push<bool>(context, PurchaseOrderScreen(poId: poId));

  /// Pops `true` when a delivery was received.
  static Future<bool?> receiveDelivery(
    BuildContext context,
    PurchaseOrderDetail po,
  ) => _push<bool>(context, ReceiveDeliveryScreen(po: po));

  /// Orders waiting to go out from [location] (else the selected store), to pick together.
  static Future<void> pickOrders(
    BuildContext context, {
    StockLocation? location,
  }) => _push<Object?>(context, PickOrdersScreen(location: location));

  /// Pops `true` when something was sent out.
  static Future<bool?> pickWalk(
    BuildContext context, {
    required String locationId,
    required List<String> orderIds,
  }) => _push<bool>(
    context,
    PickWalkScreen(locationId: locationId, orderIds: orderIds),
  );

  /// Move pieces from one store to another.
  static Future<void> moveStock(BuildContext context) =>
      _push<Object?>(context, const TransferScreen());

  static Future<void> stockCount(BuildContext context, String countId) =>
      _push<Object?>(context, StockCountScreen(countId: countId));

  /// A counter bill's receipt, from the order it belongs to.
  static Future<void> receipt(BuildContext context, String orderId) =>
      _push<Object?>(context, ReceiptScreen(orderId: orderId));
}

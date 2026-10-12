import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_endpoints.dart';

void main() {
  test('every endpoint builds the path the backend expects', () {
    expect(ApiEndpoints.login, '/auth/login');
    expect(ApiEndpoints.logout, '/auth/logout');
    expect(ApiEndpoints.session, '/auth/session');
    expect(ApiEndpoints.me, '/auth/me');
    expect(ApiEndpoints.myPassword, '/auth/me/password');
    expect(ApiEndpoints.signOutOtherDevices, '/auth/me/sign-out-other-devices');
    expect(ApiEndpoints.branding, '/branding');
    expect(ApiEndpoints.brandingDetails, '/branding/details');
    expect(ApiEndpoints.brandingName, '/branding/name');
    expect(ApiEndpoints.locations, '/locations');
    expect(ApiEndpoints.dashboardSummary, '/dashboard/summary');
    expect(ApiEndpoints.products, '/products');
    expect(ApiEndpoints.productVariants('p1'), '/products/p1/variants');
    expect(ApiEndpoints.variantSearch, '/variants/search');
    expect(ApiEndpoints.inventoryVariants, '/inventory/variants');
    expect(ApiEndpoints.inventoryTransactions, '/inventory/transactions');
    expect(ApiEndpoints.stockIn, '/inventory/stock-in');
    expect(ApiEndpoints.stockOut, '/inventory/stock-out');
    expect(ApiEndpoints.salesOrders, '/sales-orders');
    expect(ApiEndpoints.salesOrder('x1'), '/sales-orders/x1');
    expect(ApiEndpoints.shelfSpots('L1'), '/shelves/locations/L1/spots');
    expect(ApiEndpoints.notShelved('L1'), '/shelves/locations/L1/not-shelved');
    expect(ApiEndpoints.scanSpot, '/shelves/spots/scan');
    expect(ApiEndpoints.spot('s1'), '/shelves/spots/s1');
    expect(ApiEndpoints.findOnShelves, '/shelves/find');
    expect(ApiEndpoints.putAway, '/shelves/putaway');
    expect(ApiEndpoints.moveOnShelves, '/shelves/move');
    expect(ApiEndpoints.customers, '/customers');
    expect(ApiEndpoints.customer('x1'), '/customers/x1');
    expect(
      ApiEndpoints.customerByPhone('+91 98765'),
      '/customers/by-phone/%2B91%2098765',
    );
    expect(ApiEndpoints.suppliers, '/suppliers');
    expect(ApiEndpoints.purchaseOrders, '/purchase-orders');
    expect(ApiEndpoints.purchaseOrder('x1'), '/purchase-orders/x1');
    expect(
      ApiEndpoints.receivePurchaseOrder('x1'),
      '/purchase-orders/x1/receive',
    );
    expect(ApiEndpoints.teamMembers, '/team/members');
  });
}

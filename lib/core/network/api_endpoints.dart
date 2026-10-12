import 'package:scaleezy/core/network/api_client.dart';

/// Every backend path the app calls, relative to [kApiBaseUrl]. Repositories use these;
/// screens never build paths themselves. Check `inventory_backend/src/routes` when adding one.
abstract final class ApiEndpoints {
  // Auth
  static const login = '/auth/login';
  static const logout = '/auth/logout';
  static const session = '/auth/session';
  static const me = '/auth/me';
  static const myPassword = '/auth/me/password';
  static const signOutOtherDevices = '/auth/me/sign-out-other-devices';

  // Shop
  static const branding = '/branding';
  static const brandingDetails = '/branding/details';
  static const brandingName = '/branding/name';
  static const locations = '/locations';

  // Dashboard
  static const dashboardSummary = '/dashboard/summary';

  // Products
  static const products = '/products';
  static String productVariants(String productId) =>
      '/products/$productId/variants';
  static const variantSearch = '/variants/search';

  // Inventory
  static const inventoryVariants = '/inventory/variants';
  static const inventoryTransactions = '/inventory/transactions';
  static const stockIn = '/inventory/stock-in';
  static const stockOut = '/inventory/stock-out';

  // Sales orders
  static const salesOrders = '/sales-orders';
  static String salesOrder(String id) => '/sales-orders/$id';

  // Shelves
  static String shelfSpots(String locationId) =>
      '/shelves/locations/$locationId/spots';
  static String notShelved(String locationId) =>
      '/shelves/locations/$locationId/not-shelved';
  static const scanSpot = '/shelves/spots/scan';
  static String spot(String spotId) => '/shelves/spots/$spotId';
  static const findOnShelves = '/shelves/find';
  static const putAway = '/shelves/putaway';
  static const moveOnShelves = '/shelves/move';

  // Customers
  static const customers = '/customers';
  static String customer(String id) => '/customers/$id';
  static String customerByPhone(String phone) =>
      '/customers/by-phone/${Uri.encodeComponent(phone)}';

  // Buying
  static const suppliers = '/suppliers';
  static const purchaseOrders = '/purchase-orders';
  static String purchaseOrder(String id) => '/purchase-orders/$id';
  static String receivePurchaseOrder(String id) =>
      '/purchase-orders/$id/receive';

  // Team
  static const teamMembers = '/team/members';
}

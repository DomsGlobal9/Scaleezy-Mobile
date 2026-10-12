import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/network/api_endpoints.dart';
import 'package:scaleezy/core/utils/json_parse.dart';
import 'package:scaleezy/features/customers/data/customer_models.dart';

/// Customers. Permissions noted per call.
class CustomerRepository {
  CustomerRepository([ApiClient? client]) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// customer:view. A bare array.
  Future<List<Customer>> customers({String? search}) async => asMaps(
    dataOf(
      await _api.get(ApiEndpoints.customers, query: {'search': search?.trim()}),
    ),
  ).map(Customer.fromJson).toList();

  /// customer:view. Includes recent orders.
  Future<Customer> customer(String id) async => Customer.fromJson(
    asMap(dataOf(await _api.get(ApiEndpoints.customer(id)))),
  );

  /// customer:view. Answers even with loyalty off (`enabled: false`); the
  /// latest 100 changes.
  Future<CustomerPoints> customerPoints(String id) async =>
      CustomerPoints.fromJson(
        asMap(dataOf(await _api.get(ApiEndpoints.customerLoyalty(id)))),
      );

  /// customer:view. The latest 100 changes.
  Future<StoreCredit> storeCredit(String id) async => StoreCredit.fromJson(
    asMap(dataOf(await _api.get(ApiEndpoints.customerStoreCredit(id)))),
  );

  /// customer:view. Null when no customer has that number.
  Future<Customer?> customerByPhone(String phone) async {
    final data = dataOf(
      await _api.get(ApiEndpoints.customerByPhone(phone.trim())),
    );
    return data is Map && data['id'] != null
        ? Customer.fromJson(Map<String, dynamic>.from(data))
        : null;
  }

  /// customer:create
  Future<Customer> createCustomer({
    required String name,
    required String phone,
    String? email,
  }) async => Customer.fromJson(
    asMap(
      dataOf(
        await _api.post(
          ApiEndpoints.customers,
          body: {
            'name': name.trim(),
            'phone': phone.trim(),
            if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          },
        ),
      ),
    ),
  );

  /// customer:update
  Future<Customer> updateCustomer(
    String id, {
    String? name,
    String? phone,
    String? email,
  }) async => Customer.fromJson(
    asMap(
      dataOf(
        await _api.patch(
          ApiEndpoints.customer(id),
          body: {
            'name': ?name?.trim(),
            'phone': ?phone?.trim(),
            if (email != null)
              'email': email.trim().isEmpty ? null : email.trim(),
          },
        ),
      ),
    ),
  );
}

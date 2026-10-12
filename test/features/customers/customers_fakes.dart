import 'package:dio/dio.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/customers/data/customer_models.dart';
import 'package:scaleezy/features/customers/data/customer_repository.dart';

/// A client that is never called: the fakes below answer instead.
ApiClient offlineClient() => ApiClient.withDio(Dio());

Customer customer(String id, {String name = 'Asha Rao', String? phone}) =>
    Customer.fromJson({
      'id': id,
      'customerCode': 'CUS-$id',
      'name': name,
      'phone': ?phone,
      'status': 'ACTIVE',
    });

/// Records each call and answers with the matching function.
class FakeCustomerRepository extends CustomerRepository {
  FakeCustomerRepository({
    this.list,
    this.one,
    this.saveAnswer,
    this.points,
    this.credit,
  }) : super(offlineClient());

  Future<List<Customer>> Function(String? search)? list;
  Future<Customer> Function(String id)? one;
  Future<Customer> Function()? saveAnswer;

  /// Unset: the call fails, as with no permission.
  Future<CustomerPoints> Function(String id)? points;
  Future<StoreCredit> Function(String id)? credit;
  final searches = <String?>[];
  final saves = <Map<String, Object?>>[];

  @override
  Future<List<Customer>> customers({String? search}) {
    searches.add(search);
    return list!(search);
  }

  @override
  Future<Customer> customer(String id) => one!(id);

  @override
  Future<CustomerPoints> customerPoints(String id) =>
      points?.call(id) ?? Future.error(_forbidden);

  @override
  Future<StoreCredit> storeCredit(String id) =>
      credit?.call(id) ?? Future.error(_forbidden);

  static const _forbidden = ApiException(
    'Seeing customers is not part of your role.',
    statusCode: 403,
  );

  @override
  Future<Customer> createCustomer({
    required String name,
    required String phone,
    String? email,
  }) {
    saves.add({'op': 'create', 'name': name, 'phone': phone, 'email': email});
    return saveAnswer!();
  }

  @override
  Future<Customer> updateCustomer(
    String id, {
    String? name,
    String? phone,
    String? email,
  }) {
    saves.add({
      'op': 'update',
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
    });
    return saveAnswer!();
  }
}

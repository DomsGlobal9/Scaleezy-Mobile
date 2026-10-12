import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/network/api_endpoints.dart';

/// The signed-in person's own account. Permissions noted per call.
class AccountRepository {
  AccountRepository([ApiClient? client]) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<void> updateMyName(String name) =>
      _api.patch(ApiEndpoints.me, body: {'name': name.trim()});

  Future<void> changeMyPassword(String currentPassword, String newPassword) =>
      _api.post(
        ApiEndpoints.myPassword,
        body: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );

  Future<void> signOutOtherDevices() =>
      _api.post(ApiEndpoints.signOutOtherDevices);
}

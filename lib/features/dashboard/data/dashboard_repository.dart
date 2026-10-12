import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/network/api_endpoints.dart';
import 'package:scaleezy/core/utils/json_parse.dart';
import 'package:scaleezy/features/dashboard/data/dashboard_models.dart';

/// Dashboard numbers. Permissions noted per call.
class DashboardRepository {
  DashboardRepository([ApiClient? client])
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// dashboard:view
  Future<DashboardSummary> getDashboardSummary() async =>
      DashboardSummary.fromJson(
        asMap(dataOf(await _api.get(ApiEndpoints.dashboardSummary))),
      );
}

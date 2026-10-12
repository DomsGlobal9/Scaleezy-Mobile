import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/network/api_endpoints.dart';
import 'package:scaleezy/core/utils/json_parse.dart';
import 'package:scaleezy/features/day_book/data/day_book_models.dart';

/// The day book. Read only.
class DayBookRepository {
  DayBookRepository([ApiClient? client]) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// report:financial. [date] is YYYY-MM-DD in the shop's timezone; none means the shop's today.
  /// The store is a query parameter here: this route ignores the x-location-id header.
  Future<DayBook> getDay({String? date, String? locationId}) async =>
      DayBook.fromJson(
        asMap(
          dataOf(
            await _api.get(
              ApiEndpoints.dayBook,
              query: {'date': date, 'locationId': locationId},
            ),
          ),
        ),
      );
}

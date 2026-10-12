import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/orders/data/order_models.dart';
import 'package:scaleezy/features/orders/data/order_repository.dart';

/// One order, opened from a list.
class OrderDetailsViewModel extends ViewModel {
  OrderDetailsViewModel(this.orderId, [OrderRepository? repo])
    : _repo = repo ?? OrderRepository();

  final String orderId;
  final OrderRepository _repo;

  OrderDetail? _detail;
  String? _error;

  /// Null while loading and after a failure.
  OrderDetail? get detail => _detail;
  String? get error => _error;

  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      _detail = await _repo.getOrder(orderId);
    } catch (e) {
      // Any failure, as the sheet always showed it; an ApiException reads as the server's text.
      _error = e.toString();
    }
    notifyListeners();
  }
}

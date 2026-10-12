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
  Object? _error;

  /// Null while loading and after a failure.
  OrderDetail? get detail => _detail;

  /// The failure as caught, so a 403 can show no-access rather than "try again".
  Object? get error => _error;

  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      _detail = await _repo.getOrder(orderId);
    } catch (e) {
      _error = e;
    }
    notifyListeners();
  }
}

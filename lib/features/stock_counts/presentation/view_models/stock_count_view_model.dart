import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/session/auth_user.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/stock_counts/data/stock_count_models.dart';
import 'package:scaleezy/features/stock_counts/data/stock_count_repository.dart';

/// One count: its lines with search and filters, entering counted quantities, and starting,
/// finishing or cancelling it. A count can hold every variant of the shop, so the filtered list
/// and the totals are worked out once per change, not on every read.
class StockCountViewModel extends ViewModel {
  StockCountViewModel(this.countId, [StockCountRepository? repo])
    : _repo = repo ?? StockCountRepository();

  final String countId;
  final StockCountRepository _repo;

  static const filters = {
    'TODO': 'Not counted',
    'DIFF': 'Differences',
    'ALL': 'All',
  };

  StockCount? _count;
  List<StockCountItem> _lines = const [];
  Map<String, int> _index = const {};
  String? _error;
  String _filter = 'ALL';
  String _query = '';
  bool _busy = false;
  final Set<String> _saving = {};
  final Map<String, String> _lineErrors = {};

  List<StockCountItem>? _visible;
  int? _counted;
  int? _differences;

  /// Null until the first load arrives.
  StockCount? get count => _count;
  List<StockCountItem> get lines => _lines;
  String? get error => _error;
  String get filter => _filter;
  String get query => _query;

  /// Starting, finishing or cancelling is under way.
  bool get busy => _busy;

  bool get isOpen => _count?.isOpen ?? false;

  /// Quantities can be entered only once the count is started, as on the web.
  bool get counting => _count?.status == 'IN_PROGRESS';

  bool isSaving(String itemId) => _saving.contains(itemId);
  bool get anySaving => _saving.isNotEmpty;

  /// Why the last save of this line was refused.
  String? lineError(String itemId) => _lineErrors[itemId];

  /// Only the shop owner may call a count off, and only while it is open.
  bool canCancel(AuthUser? user) => isOpen && (user?.isOwner ?? false);

  int get total => _lines.length;
  int get counted => _counted ??= _lines.where((l) => l.counted != null).length;
  int get uncounted => total - counted;
  int get differences => _differences ??= _lines
      .where((l) => l.counted != null && l.counted != l.expected)
      .length;

  /// How many lines a filter shows, before searching.
  int countOf(String filter) => switch (filter) {
    'TODO' => uncounted,
    'DIFF' => differences,
    _ => total,
  };

  /// The lines in the chosen filter that match the search.
  List<StockCountItem> get visible => _visible ??= _lines.where((l) {
    final inFilter = switch (_filter) {
      'TODO' => l.counted == null,
      'DIFF' => l.counted != null && l.counted != l.expected,
      _ => true,
    };
    return inFilter && (_query.isEmpty || l.searchText.contains(_query));
  }).toList();

  void _changed() {
    _visible = null;
    _counted = null;
    _differences = null;
    notifyListeners();
  }

  /// stock_count:view
  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      final detail = await _repo.stockCount(countId);
      _count = detail.count;
      _lines = detail.items;
      _index = {for (final (i, l) in _lines.indexed) l.id: i};
    } on ApiException catch (e) {
      _error = e.message;
    }
    _changed();
  }

  void search(String query) {
    final q = query.trim().toLowerCase();
    if (q == _query) return;
    _query = q;
    _changed();
  }

  void selectFilter(String filter) {
    if (filter == _filter) return;
    _filter = filter;
    _changed();
  }

  /// The line a scanned or typed code belongs to; null when it is not on this count.
  StockCountItem? find(String code) {
    final c = code.trim();
    if (c.isEmpty) return null;
    return _lines.where((l) => l.matchesCode(c)).firstOrNull;
  }

  /// stock_count:update. [value] null puts the line back to "not counted". The line changes
  /// only once the server has it, so a number on screen is always a saved one. Null on
  /// success, otherwise the server's message (also kept as [lineError]).
  Future<String?> setCounted(String itemId, int? value) async {
    if (_saving.contains(itemId)) {
      return 'Still saving this line. Try again in a moment.';
    }
    _saving.add(itemId);
    _lineErrors.remove(itemId);
    notifyListeners();
    try {
      final saved = await _repo.setCounted(countId, itemId, value);
      final i = _index[itemId];
      if (i != null) {
        _lines = List.of(_lines)
          ..[i] = _lines[i].withCount(
            expected: saved.expected,
            counted: saved.counted,
          );
      }
      return null;
    } on ApiException catch (e) {
      _lineErrors[itemId] = e.message;
      return e.message;
    } finally {
      _saving.remove(itemId);
      _changed();
    }
  }

  /// One more piece on a line.
  Future<String?> addOne(String itemId) {
    final line = _lines[_index[itemId]!];
    return setCounted(itemId, (line.counted ?? 0) + 1);
  }

  /// stock_count:create. DRAFT -> IN_PROGRESS.
  Future<String?> start() => _act(() => _repo.startStockCount(countId));

  /// stock_count:complete. Afterwards [count] carries accuracy and the corrected lines.
  Future<String?> complete() => _act(() => _repo.completeStockCount(countId));

  /// The shop owner only.
  Future<String?> cancel() => _act(() => _repo.cancelStockCount(countId));

  // The lines themselves do not change when the count moves on, so only the count is replaced.
  Future<String?> _act(Future<StockCount> Function() call) async {
    _busy = true;
    notifyListeners();
    try {
      _count = await call();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}

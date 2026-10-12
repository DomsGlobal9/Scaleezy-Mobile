import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/picking/data/picking_models.dart';
import 'package:scaleezy/features/picking/data/picking_repository.dart';

/// One line of the walk: pieces of one order line at one shelf, or not on any shelf.
class PickTask {
  final String key;

  /// Null when the pieces are not on a shelf.
  final PickStop? stop;
  final Pick pick;

  const PickTask(this.key, this.stop, this.pick);
}

/// What sending out did: how many orders went, and a line per order that did not.
typedef SendOutcome = ({int sent, List<String> problems});

/// One walk through the shelves for the chosen orders: tick off pieces, report what is not
/// there, then send out what was picked. Nothing changes on the server until [sendOut], except
/// a not-found report.
class PickWalkViewModel extends ViewModel {
  PickWalkViewModel({
    required this.locationId,
    required this.orderIds,
    PickingRepository? repo,
  }) : _repo = repo ?? PickingRepository();

  final String locationId;
  final List<String> orderIds;
  final PickingRepository _repo;

  PickList? _list;
  List<PickTask> _tasks = const [];
  String? _error;
  final Map<String, int> _picked = {};
  final Map<String, int> _missing = {};
  bool _reporting = false;
  bool _sending = false;

  /// Null until the list arrives.
  PickList? get list => _list;
  List<PickTask> get tasks => _tasks;
  String? get error => _error;

  /// A not-found report is on its way.
  bool get reporting => _reporting;
  bool get sending => _sending;

  /// Pieces in hand for [t].
  int picked(PickTask t) => _picked[t.key] ?? 0;

  /// Pieces reported as not on the shelf for [t].
  int missing(PickTask t) => _missing[t.key] ?? 0;
  bool isDone(PickTask t) => picked(t) + missing(t) >= t.pick.quantity;
  int get doneCount => _tasks.where(isDone).length;
  bool get allDone => _tasks.isNotEmpty && doneCount == _tasks.length;
  int get readyPieces => _picked.values.fold(0, (a, b) => a + b);

  /// Orders with at least one piece picked.
  int get readyOrders => _tasks
      .where((t) => picked(t) > 0)
      .map((t) => t.pick.orderId)
      .toSet()
      .length;

  /// The first line still to pick, in walking order.
  PickTask? get current => _tasks.where((t) => !isDone(t)).firstOrNull;

  PickTask? task(String key) => _tasks.where((t) => t.key == key).firstOrNull;

  /// shelf:putaway
  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      final list = await _repo.pickList(locationId, orderIds);
      if (disposed) return;
      _list = list;
      _tasks = [
        for (final s in list.stops)
          for (final p in s.picks)
            PickTask('${s.spotId}|${p.salesOrderItemId}', s, p),
        for (final p in list.notShelved)
          PickTask('loose|${p.salesOrderItemId}', null, p),
      ];
    } on ApiException catch (e) {
      if (disposed) return;
      _error = e.message;
    }
    notifyListeners();
  }

  /// Sets the pieces in hand for [t], up to what is still to find there.
  void setPicked(PickTask t, int n) {
    _picked[t.key] = n.clamp(0, t.pick.quantity - missing(t));
    notifyListeners();
  }

  /// Everything of [t] is in hand.
  void pickAll(PickTask t) => setPicked(t, t.pick.quantity);

  /// A shelf label's QR holds "SEZ:" and a code.
  static final _label = RegExp(
    r'^\s*sez:\s*[a-z0-9]{6,16}\s*$',
    caseSensitive: false,
  );

  /// A scanned shelf label checks the person is at the right shelf; a scanned piece counts one
  /// against its line, the current one first. Returns what to tell the person.
  String scan(String code) {
    final now = current;
    if (now == null) return 'Everything is picked.';
    if (_label.hasMatch(code)) {
      final label = code.trim().toUpperCase().replaceFirst(
        RegExp(r'^SEZ:\s*'),
        '',
      );
      final stop = now.stop;
      if (stop == null) return 'This piece is not on a shelf; scan the item.';
      return stop.labelCode == label
          ? 'At ${stop.address}. Now scan the item.'
          : 'That is not ${stop.address}.';
    }
    final matches = _tasks.where(
      (t) => !isDone(t) && t.pick.item.matches(code),
    );
    final t =
        matches.where((t) => t.key == now.key).firstOrNull ??
        matches.firstOrNull;
    if (t == null) {
      return '"${code.trim()}" is not on this pick list, or all of it is picked.';
    }
    setPicked(t, picked(t) + 1);
    return '+1  ${t.pick.item.title}  (${picked(t)}/${t.pick.quantity})';
  }

  /// shelf:putaway. The rest of [t] is not on its shelf: recorded so someone counts that shelf.
  /// What was found is kept. Null when it worked, else the server's message.
  Future<String?> reportNotFound(PickTask t) async {
    final stop = t.stop;
    final gone = t.pick.quantity - picked(t) - missing(t);
    if (stop == null || gone <= 0 || _reporting) return null;
    _reporting = true;
    notifyListeners();
    try {
      await _repo.reportNotFound(
        spotId: stop.spotId,
        variantId: t.pick.item.variantId,
        missing: gone,
      );
      _missing[t.key] = missing(t) + gone;
      return null;
    } on ApiException catch (e) {
      return e.message;
    } finally {
      _reporting = false;
      notifyListeners();
    }
  }

  /// What would go out for [orderId]: picked pieces per order line, with the shelves they came
  /// from (the web's rule: a line taken only off no shelf names none).
  List<DispatchLine> linesFor(String orderId) {
    final lines = <String, (int, Map<String, int>)>{};
    for (final t in _tasks.where((t) => t.pick.orderId == orderId)) {
      final got = picked(t);
      if (got == 0) continue;
      final id = t.pick.salesOrderItemId;
      final (qty, spots) = lines[id] ?? (0, <String, int>{});
      if (t.stop != null) spots[t.stop!.spotId] = got;
      lines[id] = (qty + got, spots);
    }
    return [
      for (final e in lines.entries)
        DispatchLine(
          salesOrderItemId: e.key,
          quantity: e.value.$1,
          fromSpots: e.value.$2,
        ),
    ];
  }

  /// dispatch:create. Sends out what was picked, one dispatch per order. Dispatch is not
  /// idempotent, so a second call while one runs, or after something went out (the screen then
  /// closes), does nothing and returns null.
  Future<SendOutcome?> sendOut() async {
    final list = _list;
    if (_sending || list == null) return null;
    _sending = true;
    notifyListeners();
    var sent = 0;
    final problems = <String>[];
    for (final MapEntry(key: id, value: number) in list.orders.entries) {
      final lines = linesFor(id);
      if (lines.isEmpty) continue;
      try {
        await _repo.dispatch(id, lines);
        sent++;
      } on ApiException catch (e) {
        problems.add('$number: ${e.message}');
      }
    }
    // Once anything went out the walk is over; staying busy keeps it from going twice.
    if (sent == 0) {
      _sending = false;
      notifyListeners();
    }
    return (sent: sent, problems: problems);
  }
}

import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/view_model/view_model.dart';
import 'package:scaleezy/features/team/data/team_models.dart';
import 'package:scaleezy/features/team/data/team_repository.dart';

/// The people on the team, active ones first, most recently seen first.
class TeamViewModel extends ViewModel {
  TeamViewModel([TeamRepository? repo]) : _repo = repo ?? TeamRepository();

  final TeamRepository _repo;

  List<TeamMember>? _members;
  ApiException? _failure;

  /// Null until the first load arrives.
  List<TeamMember>? get members => _members;
  String? get error => _failure?.message;

  /// The last failed load, kept whole so a 403 shows as no access.
  ApiException? get failure => _failure;

  /// Seen in the last 15 minutes.
  static bool isOnline(TeamMember m) =>
      m.lastActiveAt != null &&
      DateTime.now().difference(m.lastActiveAt!).inMinutes < 15;

  int get activeNow =>
      (_members ?? const <TeamMember>[]).where(isOnline).length;

  /// admin:users
  Future<void> load() async {
    _failure = null;
    notifyListeners();
    try {
      _members = [...await _repo.team()]
        ..sort((a, b) {
          if (a.status != b.status) return a.status == 'ACTIVE' ? -1 : 1;
          return (b.lastActiveAt ?? DateTime(0)).compareTo(
            a.lastActiveAt ?? DateTime(0),
          );
        });
    } on ApiException catch (e) {
      _failure = e;
    }
    notifyListeners();
  }
}

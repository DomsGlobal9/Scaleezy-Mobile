import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_session.dart';
import '../../api/module_repository.dart';
import '../../models/module_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_state.dart';
import '../../widgets/ui.dart';
import 'customers_screen.dart' show avatarColour, launchContact;

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  List<TeamMember>? _members;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final m = await ModuleRepository().team();
      if (mounted) setState(() => _members = m);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = SessionScope.of(context).user?.id;
    final members = [...?_members]
      ..sort((a, b) {
        if (a.status != b.status) return a.status == 'ACTIVE' ? -1 : 1;
        return (b.lastActiveAt ?? DateTime(0)).compareTo(
          a.lastActiveAt ?? DateTime(0),
        );
      });
    final activeNow = members
        .where(
          (m) =>
              m.lastActiveAt != null &&
              DateTime.now().difference(m.lastActiveAt!).inMinutes < 15,
        )
        .length;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentGold,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              PageHeader(
                title: 'Team & Users',
                subtitle: _members == null
                    ? null
                    : '${members.length} people • $activeNow active now',
              ),
              if (_members == null && _error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: ErrorView(message: _error!, onRetry: _load),
                )
              else if (_members == null)
                for (var i = 0; i < 4; i++)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Skeleton(height: 76, radius: 18),
                  )
              else ...[
                for (final (i, m) in members.indexed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: _card(m, isMe: m.id == me).entrance(i % 15),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(28, 8, 28, 0),
                  child: Text(
                    'Adding people and changing roles is done from the web app, where the full permission list fits.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(TeamMember m, {required bool isMe}) {
    final colour = avatarColour(m.id);
    final online =
        m.lastActiveAt != null &&
        DateTime.now().difference(m.lastActiveAt!).inMinutes < 15;
    final inactive = m.status != 'ACTIVE';
    return Opacity(
      opacity: inactive ? 0.6 : 1,
      child: SurfaceCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colour.withValues(alpha: 0.12),
                  child: Text(
                    initialsOf(m.name),
                    style: TextStyle(
                      color: colour,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (online)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.accentSuccess,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          m.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isMe)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentGoldLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accentGold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (m.roles.isNotEmpty) m.roles.join(', '),
                      if (inactive)
                        m.status.toLowerCase()
                      else if (m.lastActiveAt != null)
                        online
                            ? 'active now'
                            : 'seen ${relativeTime(m.lastActiveAt!)}',
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (!isMe)
              IconButton(
                tooltip: 'Email',
                onPressed: () => launchContact(
                  context,
                  Uri(scheme: 'mailto', path: m.email),
                ),
                icon: const Icon(
                  Icons.mail_outline_rounded,
                  color: AppColors.accentBlue,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:scaleezy/core/session/auth_session.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/utils/contact_utils.dart';
import 'package:scaleezy/core/utils/labels.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/status_pill.dart';
import 'package:scaleezy/core/widgets/ui.dart';
import 'package:scaleezy/features/team/data/team_models.dart';
import 'package:scaleezy/features/team/presentation/view_models/team_view_model.dart';

class TeamScreen extends StatefulWidget {
  /// Tests pass their own; otherwise the screen makes and owns one.
  final TeamViewModel? viewModel;

  const TeamScreen({super.key, this.viewModel});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late final TeamViewModel _vm = widget.viewModel ?? TeamViewModel();

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildScreen(),
    );
  }

  Widget _buildScreen() {
    final me = SessionScope.of(context).user?.id;
    final members = _vm.members;
    final failure = _vm.failure;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _vm.load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              PageHeader(
                title: 'Team & Users',
                subtitle: members == null
                    ? null
                    : '${members.length} people • ${_vm.activeNow} active now',
              ),
              if (members == null && failure != null)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: ErrorView.fromError(
                    failure,
                    what: 'the team',
                    onRetry: _vm.load,
                  ),
                )
              else if (members == null)
                for (var i = 0; i < 4; i++)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Skeleton(height: 76),
                  )
              else ...[
                for (final (i, m) in members.indexed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _card(m, isMe: m.id == me).entrance(i % 15),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                  child: Text(
                    'Adding people and changing roles is done from the web app, where the full permission list fits.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      fontWeight: FontWeight.w400,
                      color: context.colors.textMuted,
                    ),
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
    final colors = context.colors;
    final type = Theme.of(context).textTheme;
    final online = TeamViewModel.isOnline(m);
    final active = m.status == 'ACTIVE';
    final seen = m.lastActiveAt == null
        ? null
        : online
        ? 'active now'
        : 'seen ${relativeTime(m.lastActiveAt!)}';
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          text: m.name,
                          children: [
                            if (isMe)
                              TextSpan(
                                text: ' (you)',
                                style: type.bodyMedium!.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // The website colours a person's status green when active, red otherwise.
                    StatusPill(
                      describe(const {}, m.status),
                      active ? Tone.success : Tone.danger,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  m.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.labelMedium!.copyWith(
                    fontWeight: FontWeight.w400,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: m.roles.isEmpty
                            ? 'Team member'
                            : m.roles.map(roleName).join(', '),
                      ),
                      if (seen != null) ...[
                        const TextSpan(text: ' · '),
                        TextSpan(
                          text: seen,
                          style: online
                              ? TextStyle(color: colors.success)
                              : null,
                        ),
                      ],
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySmall,
                ),
              ],
            ),
          ),
          if (!isMe)
            IconButton(
              tooltip: 'Email',
              onPressed: () =>
                  launchContact(context, Uri(scheme: 'mailto', path: m.email)),
              icon: Icon(
                Icons.mail_outline_rounded,
                color: colors.info,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}

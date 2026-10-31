import 'package:flutter/material.dart';

import '../models/match_detail.dart';

/// Organizer's roll call. Everyone starts ticked, so clearing the players who
/// did not turn up is one tap each. Pops with the list of present user ids.
class AttendanceSheet extends StatefulWidget {
  const AttendanceSheet({super.key, required this.detail});

  final MatchDetail detail;

  @override
  State<AttendanceSheet> createState() => _AttendanceSheetState();
}

class _AttendanceSheetState extends State<AttendanceSheet> {
  late final List<MatchPlayer> _players = widget.detail.confirmedPlayers;

  /// A player stays ticked until the organizer clears them, and players
  /// already saved as absent reopen unticked.
  late final Set<String> _present = {
    for (final player in _players)
      if (player.attended != false) player.userId,
  };

  String _sideLabel(MatchPlayer player) {
    final match = widget.detail.match;
    if (!match.isChallenge) return 'Team ${player.team ?? 'A'}';
    return player.team == 'B'
        ? (match.opponentOrganizationName ?? 'Opponent')
        : (match.organizationName ?? 'Host club');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final allPresent = _present.length == _players.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Take attendance',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Clear anyone who did not turn up. Unchecked players are '
                'recorded as no-shows — you can change this until you '
                'complete the match.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (_players.isEmpty)
                Text(
                  'No confirmed players to mark.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final player in _players)
                          CheckboxListTile(
                            value: _present.contains(player.userId),
                            onChanged: (checked) => setState(() {
                              if (checked == true) {
                                _present.add(player.userId);
                              } else {
                                _present.remove(player.userId);
                              }
                            }),
                            title: Text(
                              player.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(_sideLabel(player)),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_present.length} of ${_players.length} present',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!allPresent && _players.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() {
                        _present.addAll(
                          _players.map((player) => player.userId),
                        );
                      }),
                      child: const Text('All present'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _players.isEmpty
                    ? null
                    : () =>
                          Navigator.of(context)
                              .pop(List<String>.from(_present)),
                child: const Text('Save attendance'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

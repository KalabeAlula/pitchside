import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/constants/addis_sub_cities.dart';
import '../core/time/addis_time.dart';
import '../models/match_model.dart';
import '../models/organization.dart';
import '../providers/match_detail_provider.dart';
import '../providers/match_feed_provider.dart';
import '../providers/organizations_provider.dart';
import 'create_match_screen.dart';
import 'match_detail_screen.dart';

/// One club: who is in it, the matches it has coming up, and — for owners and
/// managers — the join code and incoming challenges.
class OrgDetailScreen extends ConsumerStatefulWidget {
  const OrgDetailScreen({
    super.key,
    required this.organization,
    required this.role,
  });

  final Organization organization;

  /// The seat the player had when they opened the club.
  final String role;

  @override
  ConsumerState<OrgDetailScreen> createState() => _OrgDetailScreenState();
}

class _OrgDetailScreenState extends ConsumerState<OrgDetailScreen> {
  bool _busy = false;

  OrganizationMembership? _membershipOf(List<OrganizationMembership>? items) {
    if (items == null) return null;
    for (final membership in items) {
      if (membership.organization.id == widget.organization.id) {
        return membership;
      }
    }
    return null;
  }

  Future<void> _host(Organization organization) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateMatchScreen(organization: organization),
      ),
    );
    if (created == true) {
      ref.invalidate(orgMatchesProvider);
      ref.invalidate(matchFeedProvider);
    }
  }

  Future<void> _openMatch(MatchOverview match) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MatchDetailScreen(matchId: match.id, initialMatch: match),
      ),
    );
    ref.invalidate(orgMatchesProvider);
  }

  Future<void> _respond(MatchOverview match, {required bool accept}) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(matchActionControllerProvider.notifier)
          .respond(match.id, accept: accept);
      ref.invalidate(orgMatchesProvider);
      if (!mounted) return;
      _toast(
        accept
            ? 'Challenge accepted. Your players can join now.'
            : 'Challenge declined and the field block released.',
      );
    } catch (error) {
      if (mounted) _toast(matchActionErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave(Organization organization, bool isOwner) async {
    if (isOwner) {
      _toast('The owner cannot leave the club.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Leave ${organization.name}?'),
        content: const Text(
          'Your club matches stay on the calendar. You can rejoin later with '
          'the club code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave club'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(leaveOrganizationControllerProvider.notifier)
          .leave(organization.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        _toast(organizationErrorMessage(error));
      }
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _toast('Join code copied.');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final memberships = ref.watch(myOrganizationsProvider).value;
    final membership = _membershipOf(memberships);
    final organization = membership?.organization ?? widget.organization;
    final role = membership?.role ?? widget.role;
    final isOwner = role == 'owner';
    final canManage = isOwner || role == 'manager';

    final matches = ref.watch(orgMatchesProvider(organization.id));
    final members = ref.watch(organizationMembersProvider(organization.id));

    return Scaffold(
      appBar: AppBar(title: Text(organization.name)),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _host(organization),
              icon: const Icon(Icons.add),
              label: const Text('Host a match'),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myOrganizationsProvider);
            ref.invalidate(orgMatchesProvider(organization.id));
            await ref.read(orgMatchesProvider(organization.id).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _ClubHeader(
                organization: organization,
                roleLabel: membership?.roleLabel ?? _roleLabel(role),
                memberCount: members.value?.length,
              ),
              if (canManage) ...[
                const SizedBox(height: 16),
                _JoinCodeCard(
                  code: ref.watch(
                    organizationJoinCodeProvider(organization.id),
                  ),
                  onCopy: _copyCode,
                ),
              ],
              const SizedBox(height: 24),
              ..._challengeSection(matches, organization, canManage),
              const SizedBox(height: 20),
              _SectionTitle(
                title: 'Upcoming matches',
                trailing: matches.value?.length == null
                    ? null
                    : '${matches.value!.length}',
              ),
              const SizedBox(height: 10),
              ..._matchList(matches, canManage),
              const SizedBox(height: 24),
              _SectionTitle(
                title: 'Squad',
                trailing: members.value == null
                    ? null
                    : '${members.value!.length}',
              ),
              const SizedBox(height: 10),
              ..._memberList(members),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _leave(organization, isOwner),
                icon: const Icon(Icons.logout),
                label: Text(isOwner ? 'Owner cannot leave' : 'Leave club'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _challengeSection(
    AsyncValue<List<MatchOverview>> matches,
    Organization organization,
    bool canManage,
  ) {
    final pending = (matches.value ?? const <MatchOverview>[])
        .where(
          (match) =>
              match.challengePending &&
              match.opponentOrganizationId == organization.id,
        )
        .toList();
    if (pending.isEmpty) return const [];

    return [
      const _SectionTitle(title: 'Challenges to answer'),
      const SizedBox(height: 10),
      for (final match in pending)
        _ChallengeCard(
          match: match,
          canManage: canManage,
          busy: _busy,
          onAccept: () => _respond(match, accept: true),
          onDecline: () => _respond(match, accept: false),
          onOpen: () => _openMatch(match),
        ),
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _matchList(
    AsyncValue<List<MatchOverview>> matches,
    bool canManage,
  ) {
    return matches.when(
      loading: () => const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ],
      error: (_, _) => [
        Row(
          children: [
            const Expanded(child: Text('Could not load club matches.')),
            TextButton(
              onPressed: () => ref.invalidate(orgMatchesProvider),
              child: const Text('Try again'),
            ),
          ],
        ),
      ],
      data: (items) {
        if (items.isEmpty) {
          return [
            Text(
              canManage
                  ? 'No games scheduled. Tap “Host a match” to book a field '
                        'block for the club.'
                  : 'No games scheduled yet. Your managers will book one.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ];
        }
        return [
          for (final match in items)
            _OrgMatchTile(match: match, onTap: () => _openMatch(match)),
        ];
      },
    );
  }

  List<Widget> _memberList(AsyncValue<List<OrganizationMember>> members) {
    final theme = Theme.of(context);
    return members.when(
      loading: () => const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ],
      error: (_, _) => [
        Text(
          'Only members can see the squad list.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      data: (items) => [
        for (final member in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Text(
                    _initials(member.fullName),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    member.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  member.roleLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _roleLabel(String role) => switch (role) {
  'owner' => 'Owner',
  'manager' => 'Manager',
  _ => 'Member',
};

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

class _ClubHeader extends StatelessWidget {
  const _ClubHeader({
    required this.organization,
    required this.roleLabel,
    required this.memberCount,
  });

  final Organization organization;
  final String roleLabel;
  final int? memberCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final location = organization.subCityId == null
        ? null
        : subCityNameFor(organization.subCityId!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  organization.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  roleLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (organization.hasAbout) ...[
            const SizedBox(height: 6),
            Text(organization.about!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              if (location != null)
                _Fact(icon: Icons.place_outlined, label: location),
              if (memberCount != null && memberCount! > 0)
                _Fact(
                  icon: Icons.groups_2_outlined,
                  label:
                      '$memberCount ${memberCount == 1 ? 'player' : 'players'}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JoinCodeCard extends StatelessWidget {
  const _JoinCodeCard({required this.code, required this.onCopy});

  final AsyncValue<String?> code;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.key_outlined, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join code',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                code.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (_, _) => Text(
                    'Could not load the code.',
                    style: theme.textTheme.bodySmall,
                  ),
                  data: (value) => Text(
                    value ?? '—',
                    style: theme.textTheme.titleLarge?.copyWith(
                      letterSpacing: 4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'Share it with your players so they can join the club.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSecondaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: code.value == null ? null : () => onCopy(code.value!),
            tooltip: 'Copy join code',
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.match,
    required this.canManage,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onOpen,
  });

  final MatchOverview match;
  final bool canManage;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final startsAt = addisWall(match.startsAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${match.organizationName ?? 'A club'} challenged you',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat('EEE, d MMM').format(startsAt)} · '
            '${DateFormat('HH:mm').format(startsAt)} $eatLabel · '
            '${match.pitchName}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${match.formatLabel} · hosted and paid by '
            '${match.organizationName ?? 'the challenger'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          if (canManage)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onDecline,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onAccept,
                    child: const Text('Accept'),
                  ),
                ),
              ],
            )
          else
            Text(
              'A club manager has to answer this challenge.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          TextButton(onPressed: onOpen, child: const Text('See details')),
        ],
      ),
    );
  }
}

class _OrgMatchTile extends StatelessWidget {
  const _OrgMatchTile({required this.match, required this.onTap});

  final MatchOverview match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final startsAt = addisWall(match.startsAt);
    final endsAt = addisWall(match.endsAt);
    final status = match.challengePending
        ? 'Pending'
        : match.isChallenge
        ? 'Challenge'
        : 'Club game';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(Icons.event_outlined, color: scheme.primary),
        title: Text(
          '${DateFormat('EEE, d MMM').format(startsAt)} · '
          '${DateFormat('HH:mm').format(startsAt)}–'
          '${DateFormat('HH:mm').format(endsAt)}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${match.pitchName} · ${match.clubLabel}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: match.challengePending
                ? scheme.tertiaryContainer
                : scheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: match.challengePending
                  ? scheme.onTertiaryContainer
                  : scheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          Text(
            trailing!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

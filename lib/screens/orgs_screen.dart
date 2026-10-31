import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/addis_sub_cities.dart';
import '../models/organization.dart';
import '../providers/organizations_provider.dart';
import '../providers/sub_cities_provider.dart';
import 'org_detail_screen.dart';

/// The third tab: the companies and clubs the player belongs to.
class OrgsScreen extends ConsumerWidget {
  const OrgsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final created = await Navigator.of(context).push<Organization>(
      MaterialPageRoute(builder: (_) => const CreateOrganizationScreen()),
    );
    if (created == null) return;
    ref.invalidate(myOrganizationsProvider);
    messenger.showSnackBar(
      SnackBar(content: Text('${created.name} is ready for its first game.')),
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final joined = await showDialog<Organization>(
      context: context,
      builder: (_) => const JoinOrganizationDialog(),
    );
    if (joined == null) return;
    ref.invalidate(myOrganizationsProvider);
    messenger.showSnackBar(
      SnackBar(content: Text('You joined ${joined.name}.')),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    OrganizationMembership membership,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrgDetailScreen(
          organization: membership.organization,
          role: membership.role,
        ),
      ),
    );
    ref.invalidate(myOrganizationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubs = ref.watch(myOrganizationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Clubs', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(
              'Companies & organizations',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Join with a code',
            onPressed: () => _join(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create a club',
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: clubs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ClubsError(
            error: error,
            onRetry: () => ref.invalidate(myOrganizationsProvider),
          ),
          data: (items) => RefreshIndicator(
            onRefresh: () => ref.refresh(myOrganizationsProvider.future),
            child: items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      _EmptyClubs(
                        onCreate: () => _create(context, ref),
                        onJoin: () => _join(context, ref),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final membership = items[index];
                      return _ClubCard(
                        membership: membership,
                        onTap: () => _open(context, ref, membership),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _ClubCard extends StatelessWidget {
  const _ClubCard({required this.membership, required this.onTap});

  final OrganizationMembership membership;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final club = membership.organization;
    final location = [
      if (club.subCityId != null) subCityNameFor(club.subCityId!),
      if (club.memberCount > 0)
        '${club.memberCount} ${club.memberCount == 1 ? 'member' : 'members'}',
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  club.initials,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RoleChip(
                label: membership.roleLabel,
                canManage: membership.canManage,
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.canManage});

  final String label;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: canManage
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: canManage
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _EmptyClubs extends StatelessWidget {
  const _EmptyClubs({required this.onCreate, required this.onJoin});

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Icon(
            Icons.groups_2_outlined,
            size: 48,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No club yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a club for your company or team, then host games inside '
            'the club or challenge another one.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create a club'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onJoin,
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Join with a code'),
          ),
        ],
      ),
    );
  }
}

class _ClubsError extends StatelessWidget {
  const _ClubsError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 44,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load your clubs',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateOrganizationScreen extends ConsumerStatefulWidget {
  const CreateOrganizationScreen({super.key});

  @override
  ConsumerState<CreateOrganizationScreen> createState() =>
      _CreateOrganizationScreenState();
}

class _CreateOrganizationScreenState
    extends ConsumerState<CreateOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();

  String? _subCityId;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final about = _aboutController.text.trim();
    try {
      final organization = await ref
          .read(createOrganizationControllerProvider.notifier)
          .create(
            name: _nameController.text.trim(),
            about: about.isEmpty ? null : about,
            subCityId: _subCityId,
          );
      if (mounted) Navigator.of(context).pop(organization);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = organizationErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subCities = ref.watch(subCitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create a club')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Give your company or team a name. You can host games '
                      'for your own players, or challenge other clubs.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      autofocus: true,
                      maxLength: 60,
                      validator: (value) {
                        final name = value?.trim() ?? '';
                        if (name.length < 2) return 'Enter the club name.';
                        if (name.length > 60) {
                          return 'Keep it under 60 characters.';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Club or company name',
                        hintText: 'Bole Rovers FC',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _aboutController,
                      maxLength: 300,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'About (optional)',
                        hintText: 'The Tuesday-night team from the 4th floor',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    subCities.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (cities) => DropdownButtonFormField<String>(
                        initialValue: _subCityId,
                        decoration: const InputDecoration(
                          labelText: 'Home sub-city (optional)',
                          border: OutlineInputBorder(),
                        ),
                        items: cities
                            .map(
                              (city) => DropdownMenuItem(
                                value: city.id,
                                child: Text(city.nameEn),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _subCityId = value),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.groups_2),
                      label: Text(
                        _submitting ? 'Creating club…' : 'Create club',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class JoinOrganizationDialog extends ConsumerStatefulWidget {
  const JoinOrganizationDialog({super.key});

  @override
  ConsumerState<JoinOrganizationDialog> createState() =>
      _JoinOrganizationDialogState();
}

class _JoinOrganizationDialogState
    extends ConsumerState<JoinOrganizationDialog> {
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'A join code is six characters.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final organization = await ref
          .read(joinOrganizationControllerProvider.notifier)
          .join(code);
      if (mounted) Navigator.of(context).pop(organization);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = organizationErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join a club'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ask your club manager for the six-character code.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              LengthLimitingTextInputFormatter(6),
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            ],
            style: const TextStyle(
              letterSpacing: 6,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: 'Join code',
              hintText: 'ABC123',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _join(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _join,
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Join'),
        ),
      ],
    );
  }
}

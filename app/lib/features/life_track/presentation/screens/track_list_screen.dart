import 'dart:async';

import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';

enum TrackListViewMode { board, list }

class TrackListScreen extends StatefulWidget {
  const TrackListScreen({
    super.key,
    this.repository,
    this.ensureInitialized,
    this.disposeOwnedResources = true,
  });

  final LifeTrackRepository? repository;
  final Future<void> Function()? ensureInitialized;
  final bool disposeOwnedResources;

  @override
  State<TrackListScreen> createState() => _TrackListScreenState();
}

class _TrackListScreenState extends State<TrackListScreen> {
  late final LifeTrackLocalDataSource? _ownedDataSource;
  late final LifeTrackRepository _repository;
  late final Future<void> _initialization;

  TrackListViewMode _viewMode = TrackListViewMode.board;
  LifeTrackCategory? _selectedCategory;
  Object? _actionError;

  @override
  void initState() {
    super.initState();

    if (widget.repository != null) {
      _ownedDataSource = null;
      _repository = widget.repository!;
      _initialization = widget.ensureInitialized?.call() ?? Future.value();
      return;
    }

    final dataSource = LifeTrackLocalDataSource();
    _ownedDataSource = dataSource;
    _repository = LifeTrackRepositoryImpl(localDataSource: dataSource);
    _initialization = dataSource.initialize();
  }

  @override
  void dispose() {
    if (widget.disposeOwnedResources) {
      unawaited(_ownedDataSource?.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LifeTrack'),
        actions: [
          SegmentedButton<TrackListViewMode>(
            key: const ValueKey('life_track_view_mode'),
            segments: const [
              ButtonSegment(
                value: TrackListViewMode.board,
                icon: Icon(Icons.view_kanban_outlined),
                label: Text('Board'),
              ),
              ButtonSegment(
                value: TrackListViewMode.list,
                icon: Icon(Icons.view_list_outlined),
                label: Text('List'),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (selection) {
              setState(() {
                _viewMode = selection.first;
              });
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _TrackListErrorState(
              message: 'LifeTrack could not open local data.',
              details: snapshot.error,
            );
          }
          return StreamBuilder<List<LifeTrack>>(
            stream: _repository.watchTracks(),
            builder: (context, trackSnapshot) {
              if (trackSnapshot.hasError) {
                return _TrackListErrorState(
                  message: 'LifeTrack could not load tracks.',
                  details: trackSnapshot.error,
                );
              }

              final tracks = trackSnapshot.data ?? const <LifeTrack>[];
              final filteredTracks = _selectedCategory == null
                  ? tracks
                  : tracks
                        .where((track) => track.category == _selectedCategory)
                        .toList(growable: false);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CategoryFilterBar(
                    selectedCategory: _selectedCategory,
                    onSelected: (category) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                  ),
                  if (_actionError != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Material(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Could not update track status: $_actionError',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: filteredTracks.isEmpty
                        ? const _TrackListEmptyState()
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _viewMode == TrackListViewMode.board
                                ? _TrackBoard(
                                    key: const ValueKey('life_track_board'),
                                    tracks: filteredTracks,
                                    onChangeStatus: _changeTrackStatus,
                                  )
                                : _TrackListView(
                                    key: const ValueKey('life_track_list'),
                                    tracks: filteredTracks,
                                    onChangeStatus: _changeTrackStatus,
                                  ),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _changeTrackStatus(LifeTrack track, TrackStatus status) async {
    setState(() {
      _actionError = null;
    });

    final updated = track.copyWith(
      status: status,
      updatedAt: DateTime.now().toUtc(),
    );
    final result = await _repository.updateTrack(updated);
    if (!mounted) return;

    if (result case Err<void>(error: final error)) {
      setState(() {
        _actionError = error;
      });
    }
  }
}

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.selectedCategory,
    required this.onSelected,
  });

  final LifeTrackCategory? selectedCategory;
  final ValueChanged<LifeTrackCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: const ValueKey('life_track_filter_all'),
              label: const Text('All'),
              selected: selectedCategory == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          ...LifeTrackCategory.values.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: ValueKey('life_track_filter_${category.name}'),
                label: Text(_categoryLabel(category)),
                selected: selectedCategory == category,
                onSelected: (_) => onSelected(category),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackBoard extends StatelessWidget {
  const _TrackBoard({
    super.key,
    required this.tracks,
    required this.onChangeStatus,
  });

  final List<LifeTrack> tracks;
  final Future<void> Function(LifeTrack, TrackStatus) onChangeStatus;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: TrackStatus.values
              .map((status) {
                final grouped = tracks
                    .where((track) => track.status == status)
                    .toList(growable: false);
                return SizedBox(
                  width: 300,
                  height: constraints.maxHeight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_statusIcon(status)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _statusLabel(status),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                Text('${grouped.length}'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: grouped.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        'No tracks',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    )
                                  : SingleChildScrollView(
                                      child: Column(
                                        children: grouped
                                            .map(
                                              (track) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 12,
                                                ),
                                                child: _TrackCard(
                                                  track: track,
                                                  compact: true,
                                                  onChangeStatus:
                                                      onChangeStatus,
                                                ),
                                              ),
                                            )
                                            .toList(growable: false),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _TrackListView extends StatelessWidget {
  const _TrackListView({
    super.key,
    required this.tracks,
    required this.onChangeStatus,
  });

  final List<LifeTrack> tracks;
  final Future<void> Function(LifeTrack, TrackStatus) onChangeStatus;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: tracks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _TrackCard(
          track: tracks[index],
          compact: false,
          onChangeStatus: onChangeStatus,
        );
      },
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.track,
    required this.compact,
    required this.onChangeStatus,
  });

  final LifeTrack track;
  final bool compact;
  final Future<void> Function(LifeTrack, TrackStatus) onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final paused = track.status == TrackStatus.postponed;
    final theme = Theme.of(context);
    final unresolvedMilestone = track.milestones.firstWhere(
      (milestone) => milestone.status != ItemStatus.done,
      orElse: () => track.milestones.isEmpty
          ? Milestone(
              id: 'empty',
              trackId: track.id,
              name: 'No milestones yet',
              objective: '',
              sortOrder: 0,
              actionItems: const [],
              status: ItemStatus.todo,
            )
          : track.milestones.first,
    );

    return Opacity(
      opacity: paused ? 0.58 : 1,
      child: Container(
        key: ValueKey('life_track_card_${track.id}'),
        decoration: BoxDecoration(
          color: paused
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: paused
                ? theme.colorScheme.outlineVariant
                : theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _categoryColor(track.category),
                    child: Icon(
                      _categoryIcon(track.category),
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _categoryLabel(track.category),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: track.progress,
                          strokeWidth: 5,
                        ),
                        Center(
                          child: Text(
                            '${(track.progress * 100).round()}%',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                compact
                    ? 'Active milestone: ${unresolvedMilestone.name}'
                    : 'Current focus: ${unresolvedMilestone.name}',
                style: theme.textTheme.bodyMedium,
              ),
              if (unresolvedMilestone.objective.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  unresolvedMilestone.objective,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatusPill(status: track.status),
                  const Spacer(),
                  PopupMenuButton<TrackStatus>(
                    key: ValueKey('life_track_actions_${track.id}'),
                    tooltip: 'Track actions',
                    onSelected: (status) => onChangeStatus(track, status),
                    itemBuilder: (context) => _actionStatuses(track.status)
                        .map(
                          (status) => PopupMenuItem<TrackStatus>(
                            value: status,
                            child: Text(_actionLabel(status)),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final TrackStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: theme.textTheme.labelMedium?.copyWith(
          color: _statusColor(status),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TrackListEmptyState extends StatelessWidget {
  const _TrackListEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.task_alt_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'No LifeTrack goals match this filter.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackListErrorState extends StatelessWidget {
  const _TrackListErrorState({required this.message, this.details});

  final String message;
  final Object? details;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (details != null) ...[
              const SizedBox(height: 8),
              Text('$details', textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

String _categoryLabel(LifeTrackCategory category) => switch (category) {
  LifeTrackCategory.realEstate => 'Real estate',
  LifeTrackCategory.education => 'Education',
  LifeTrackCategory.medical => 'Medical',
  LifeTrackCategory.insurance => 'Insurance',
  LifeTrackCategory.finance => 'Finance',
  LifeTrackCategory.travel => 'Travel',
  LifeTrackCategory.carPurchase => 'Car purchase',
  LifeTrackCategory.legal => 'Legal',
  LifeTrackCategory.custom => 'Custom',
};

String _statusLabel(TrackStatus status) => switch (status) {
  TrackStatus.draft => 'Draft',
  TrackStatus.active => 'Active',
  TrackStatus.completed => 'Completed',
  TrackStatus.archived => 'Archived',
  TrackStatus.postponed => 'Postponed',
};

String _actionLabel(TrackStatus status) => switch (status) {
  TrackStatus.active => 'Mark active',
  TrackStatus.postponed => 'Postpone',
  TrackStatus.archived => 'Archive',
  TrackStatus.completed => 'Mark completed',
  TrackStatus.draft => 'Move to draft',
};

List<TrackStatus> _actionStatuses(TrackStatus currentStatus) {
  final actions = <TrackStatus>[
    if (currentStatus != TrackStatus.active) TrackStatus.active,
    if (currentStatus != TrackStatus.postponed) TrackStatus.postponed,
    if (currentStatus != TrackStatus.archived) TrackStatus.archived,
  ];
  return actions;
}

IconData _categoryIcon(LifeTrackCategory category) => switch (category) {
  LifeTrackCategory.realEstate => Icons.home_work_outlined,
  LifeTrackCategory.education => Icons.school_outlined,
  LifeTrackCategory.medical => Icons.local_hospital_outlined,
  LifeTrackCategory.insurance => Icons.verified_user_outlined,
  LifeTrackCategory.finance => Icons.account_balance_wallet_outlined,
  LifeTrackCategory.travel => Icons.flight_takeoff_outlined,
  LifeTrackCategory.carPurchase => Icons.directions_car_outlined,
  LifeTrackCategory.legal => Icons.gavel_outlined,
  LifeTrackCategory.custom => Icons.auto_awesome_outlined,
};

Color _categoryColor(LifeTrackCategory category) => switch (category) {
  LifeTrackCategory.realEstate => const Color(0xFF1565C0),
  LifeTrackCategory.education => const Color(0xFF2E7D32),
  LifeTrackCategory.medical => const Color(0xFFC62828),
  LifeTrackCategory.insurance => const Color(0xFF6A1B9A),
  LifeTrackCategory.finance => const Color(0xFF00838F),
  LifeTrackCategory.travel => const Color(0xFFEF6C00),
  LifeTrackCategory.carPurchase => const Color(0xFF5D4037),
  LifeTrackCategory.legal => const Color(0xFF455A64),
  LifeTrackCategory.custom => const Color(0xFF7B1FA2),
};

Color _statusColor(TrackStatus status) => switch (status) {
  TrackStatus.draft => const Color(0xFF616161),
  TrackStatus.active => const Color(0xFF1565C0),
  TrackStatus.completed => const Color(0xFF2E7D32),
  TrackStatus.archived => const Color(0xFF5D4037),
  TrackStatus.postponed => const Color(0xFFEF6C00),
};

IconData _statusIcon(TrackStatus status) => switch (status) {
  TrackStatus.draft => Icons.edit_note_outlined,
  TrackStatus.active => Icons.play_circle_outline,
  TrackStatus.completed => Icons.check_circle_outline,
  TrackStatus.archived => Icons.archive_outlined,
  TrackStatus.postponed => Icons.pause_circle_outline,
};

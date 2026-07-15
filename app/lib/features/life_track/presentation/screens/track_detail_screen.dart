import 'dart:async';

import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

typedef PickLifeTrackDocument = Future<String?> Function();
typedef PickLifeTrackDate =
    Future<DateTime?> Function(BuildContext context, DateTime? initialDate);

class TrackDetailScreen extends StatefulWidget {
  const TrackDetailScreen({
    super.key,
    required this.trackId,
    this.repository,
    this.ensureInitialized,
    this.disposeOwnedResources = true,
    this.pickDocument,
    this.pickDate,
  });

  final String trackId;
  final LifeTrackRepository? repository;
  final Future<void> Function()? ensureInitialized;
  final bool disposeOwnedResources;
  final PickLifeTrackDocument? pickDocument;
  final PickLifeTrackDate? pickDate;

  @override
  State<TrackDetailScreen> createState() => _TrackDetailScreenState();
}

class _TrackDetailScreenState extends State<TrackDetailScreen> {
  late final LifeTrackLocalDataSource? _ownedDataSource;
  late final LifeTrackRepository _repository;
  late final Future<void> _initialization;
  late final PickLifeTrackDocument _pickDocument;
  late final PickLifeTrackDate _pickDate;

  Object? _mutationError;

  @override
  void initState() {
    super.initState();
    _pickDocument = widget.pickDocument ?? _defaultPickDocument;
    _pickDate = widget.pickDate ?? _defaultPickDate;

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
      appBar: AppBar(title: const Text('Track detail')),
      body: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _TrackDetailMessageState(
              icon: Icons.error_outline,
              title: 'LifeTrack could not open local data.',
              details: snapshot.error,
            );
          }

          return StreamBuilder<List<LifeTrack>>(
            stream: _repository.watchTracks(),
            builder: (context, streamSnapshot) {
              if (streamSnapshot.hasError) {
                return _TrackDetailMessageState(
                  icon: Icons.error_outline,
                  title: 'LifeTrack could not load this track.',
                  details: streamSnapshot.error,
                );
              }

              final tracks = streamSnapshot.data;
              final track = _findTrack(tracks, widget.trackId);
              if (track == null) {
                return FutureBuilder<Result<LifeTrack>>(
                  future: _repository.getTrack(widget.trackId),
                  builder: (context, detailSnapshot) {
                    if (!detailSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final result = detailSnapshot.data!;
                    if (result case Ok<LifeTrack>(value: final value)) {
                      return _TrackDetailBody(
                        track: value,
                        mutationError: _mutationError,
                        onStatusChanged: _updateItemStatus,
                        onSaveInputValue: _saveInputValue,
                        pickDocument: _pickDocument,
                        pickDate: _pickDate,
                      );
                    }
                    return _TrackDetailMessageState(
                      icon: Icons.search_off,
                      title: 'Track not found.',
                      details: result is Err<LifeTrack> ? result.error : null,
                    );
                  },
                );
              }

              return _TrackDetailBody(
                track: track,
                mutationError: _mutationError,
                onStatusChanged: _updateItemStatus,
                onSaveInputValue: _saveInputValue,
                pickDocument: _pickDocument,
                pickDate: _pickDate,
              );
            },
          );
        },
      ),
    );
  }

  LifeTrack? _findTrack(List<LifeTrack>? tracks, String trackId) {
    if (tracks == null) return null;
    for (final track in tracks) {
      if (track.id == trackId) return track;
    }
    return null;
  }

  Future<void> _updateItemStatus(String itemId, ItemStatus status) async {
    setState(() {
      _mutationError = null;
    });
    final result = await _repository.updateItemStatus(itemId, status);
    if (!mounted) return;
    if (result case Err<void>(error: final error)) {
      setState(() {
        _mutationError = error;
      });
    }
  }

  Future<void> _saveInputValue(String requirementId, String value) async {
    setState(() {
      _mutationError = null;
    });
    final result = await _repository.saveInputValue(requirementId, value);
    if (!mounted) return;
    if (result case Err<void>(error: final error)) {
      setState(() {
        _mutationError = error;
      });
    }
  }

  Future<String?> _defaultPickDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'txt',
        'doc',
        'docx',
      ],
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first.path;
  }

  Future<DateTime?> _defaultPickDate(
    BuildContext context,
    DateTime? initialDate,
  ) {
    final now = DateTime.now();
    final initial = initialDate ?? now;
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 20),
    );
  }
}

class _TrackDetailBody extends StatelessWidget {
  const _TrackDetailBody({
    required this.track,
    required this.mutationError,
    required this.onStatusChanged,
    required this.onSaveInputValue,
    required this.pickDocument,
    required this.pickDate,
  });

  final LifeTrack track;
  final Object? mutationError;
  final Future<void> Function(String itemId, ItemStatus status) onStatusChanged;
  final Future<void> Function(String requirementId, String value)
  onSaveInputValue;
  final PickLifeTrackDocument pickDocument;
  final PickLifeTrackDate pickDate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _TrackHeroCard(track: track),
        if (mutationError != null) ...[
          const SizedBox(height: 12),
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Could not update this track: $mutationError',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        ...track.milestones.map(
          (milestone) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MilestonePanel(
              milestone: milestone,
              onStatusChanged: onStatusChanged,
              onSaveInputValue: onSaveInputValue,
              pickDocument: pickDocument,
              pickDate: pickDate,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackHeroCard extends StatelessWidget {
  const _TrackHeroCard({required this.track});

  final LifeTrack track;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _categoryColor(track.category),
              child: Icon(_categoryIcon(track.category), color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_categoryLabel(track.category)} · ${_statusLabel(track.status)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: track.progress),
                  const SizedBox(height: 6),
                  Text('${(track.progress * 100).round()}% complete'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestonePanel extends StatelessWidget {
  const _MilestonePanel({
    required this.milestone,
    required this.onStatusChanged,
    required this.onSaveInputValue,
    required this.pickDocument,
    required this.pickDate,
  });

  final Milestone milestone;
  final Future<void> Function(String itemId, ItemStatus status) onStatusChanged;
  final Future<void> Function(String requirementId, String value)
  onSaveInputValue;
  final PickLifeTrackDocument pickDocument;
  final PickLifeTrackDate pickDate;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: ValueKey('life_track_milestone_${milestone.id}'),
      initiallyExpanded: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        milestone.name,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(milestone.objective),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: milestone.progress),
          ),
        ],
      ),
      trailing: _ItemStatusBadge(status: milestone.status),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: milestone.actionItems
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _ActionItemCard(
                item: item,
                onStatusChanged: onStatusChanged,
                onSaveInputValue: onSaveInputValue,
                pickDocument: pickDocument,
                pickDate: pickDate,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ActionItemCard extends StatelessWidget {
  const _ActionItemCard({
    required this.item,
    required this.onStatusChanged,
    required this.onSaveInputValue,
    required this.pickDocument,
    required this.pickDate,
  });

  final ActionItem item;
  final Future<void> Function(String itemId, ItemStatus status) onStatusChanged;
  final Future<void> Function(String requirementId, String value)
  onSaveInputValue;
  final PickLifeTrackDocument pickDocument;
  final PickLifeTrackDate pickDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('life_track_item_${item.id}'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.summary,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (item.description case final description?) ...[
                        const SizedBox(height: 4),
                        Text(description),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _ItemStatusBadge(status: item.status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ItemStatus.values
                  .map(
                    (status) => ChoiceChip(
                      key: ValueKey(
                        'life_track_status_${item.id}_${status.name}',
                      ),
                      label: Text(_itemStatusLabel(status)),
                      selected: item.status == status,
                      onSelected: item.status == status
                          ? null
                          : (_) => onStatusChanged(item.id, status),
                    ),
                  )
                  .toList(growable: false),
            ),
            if (item.requirements.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...item.requirements.map(
                (requirement) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RequirementField(
                    requirement: requirement,
                    onSaveInputValue: onSaveInputValue,
                    pickDocument: pickDocument,
                    pickDate: pickDate,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequirementField extends StatefulWidget {
  const _RequirementField({
    required this.requirement,
    required this.onSaveInputValue,
    required this.pickDocument,
    required this.pickDate,
  });

  final InputRequirement requirement;
  final Future<void> Function(String requirementId, String value)
  onSaveInputValue;
  final PickLifeTrackDocument pickDocument;
  final PickLifeTrackDate pickDate;

  @override
  State<_RequirementField> createState() => _RequirementFieldState();
}

class _RequirementFieldState extends State<_RequirementField> {
  late final TextEditingController _controller;
  late final ValueNotifier<bool> _boolValue;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.requirement.value ?? '');
    _boolValue = ValueNotifier<bool>(
      (widget.requirement.value ?? 'false') == 'true',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _boolValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requirement = widget.requirement;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          requirement.label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (requirement.hint case final hint?) ...[
          const SizedBox(height: 4),
          Text(
            hint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        switch (requirement.fieldType) {
          FieldType.boolean => ValueListenableBuilder<bool>(
            valueListenable: _boolValue,
            builder: (context, value, _) => Material(
              color: Colors.transparent,
              child: SwitchListTile.adaptive(
                key: ValueKey('life_track_bool_${requirement.id}'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Completed'),
                value: value,
                onChanged: (next) async {
                  _boolValue.value = next;
                  await widget.onSaveInputValue(
                    requirement.id,
                    next.toString(),
                  );
                },
              ),
            ),
          ),
          FieldType.document => _ActionFieldButton(
            key: ValueKey('life_track_document_${requirement.id}'),
            icon: Icons.upload_file_outlined,
            label: requirement.value?.isNotEmpty == true
                ? requirement.value!
                : 'Attach document',
            onPressed: () async {
              final path = await widget.pickDocument();
              if (!mounted || path == null) return;
              _controller.text = path;
              await widget.onSaveInputValue(requirement.id, path);
              if (!mounted) return;
              setState(() {});
            },
          ),
          FieldType.date => _ActionFieldButton(
            key: ValueKey('life_track_date_${requirement.id}'),
            icon: Icons.event_outlined,
            label: _controller.text.isEmpty ? 'Pick date' : _controller.text,
            onPressed: () async {
              final current = _controller.text.isEmpty
                  ? null
                  : DateTime.tryParse(_controller.text);
              final picked = await widget.pickDate(context, current);
              if (!mounted || picked == null) return;
              final value = picked.toUtc().toIso8601String();
              _controller.text = value;
              await widget.onSaveInputValue(requirement.id, value);
              if (!mounted) return;
              setState(() {});
            },
          ),
          _ => Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('life_track_input_${requirement.id}'),
                  controller: _controller,
                  keyboardType: requirement.fieldType == FieldType.number
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : requirement.fieldType == FieldType.link
                      ? TextInputType.url
                      : TextInputType.text,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: _fieldHint(requirement.fieldType),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: ValueKey('life_track_save_${requirement.id}'),
                onPressed: () => widget.onSaveInputValue(
                  requirement.id,
                  _controller.text.trim(),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        },
      ],
    );
  }
}

class _ActionFieldButton extends StatelessWidget {
  const _ActionFieldButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}

class _ItemStatusBadge extends StatelessWidget {
  const _ItemStatusBadge({required this.status});

  final ItemStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _itemStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _itemStatusLabel(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TrackDetailMessageState extends StatelessWidget {
  const _TrackDetailMessageState({
    required this.icon,
    required this.title,
    this.details,
  });

  final IconData icon;
  final String title;
  final Object? details;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
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

String _itemStatusLabel(ItemStatus status) => switch (status) {
  ItemStatus.todo => 'Todo',
  ItemStatus.inProgress => 'In progress',
  ItemStatus.blocked => 'Blocked',
  ItemStatus.done => 'Done',
  ItemStatus.skipped => 'Skipped',
};

String _fieldHint(FieldType type) => switch (type) {
  FieldType.text => 'Enter text',
  FieldType.link => 'Paste link',
  FieldType.number => 'Enter number',
  _ => '',
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

Color _itemStatusColor(ItemStatus status) => switch (status) {
  ItemStatus.todo => const Color(0xFF616161),
  ItemStatus.inProgress => const Color(0xFF1565C0),
  ItemStatus.blocked => const Color(0xFFC62828),
  ItemStatus.done => const Color(0xFF2E7D32),
  ItemStatus.skipped => const Color(0xFF5D4037),
};

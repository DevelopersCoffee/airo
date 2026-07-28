import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_epg/platform_epg.dart';

import '../../application/providers/richer_context_providers.dart';

/// Internal-only consent surface. With CE's null adapter it renders nothing.
class RicherContextPrototypeConsentPanel extends ConsumerWidget {
  const RicherContextPrototypeConsentPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adapter = ref.watch(richerContextAdapterProvider);
    if (adapter == null) return const SizedBox.shrink();
    final consent = ref.watch(richerContextConsentProvider);
    final descriptor = adapter.descriptor;
    return Semantics(
      container: true,
      label: '${descriptor.name} richer context prototype settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Internal richer context · ${descriptor.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(descriptor.attribution.notice),
          Text(descriptor.attribution.url.toString()),
          SwitchListTile(
            title: const Text('Programme posters and synopses'),
            subtitle: Text(
              'Allow programme-title lookups from ${descriptor.name}',
            ),
            value: consent.metadataEnabled,
            onChanged: (value) => unawaited(
              ref
                  .read(richerContextConsentProvider.notifier)
                  .setMetadataEnabled(value),
            ),
          ),
          SwitchListTile(
            title: const Text('Sports fixtures'),
            subtitle: Text(
              'Allow fixture lookups for sports channels from '
              '${descriptor.name}; no odds or betting',
            ),
            value: consent.sportsEnabled,
            onChanged: (value) => unawaited(
              ref
                  .read(richerContextConsentProvider.notifier)
                  .setSportsEnabled(value),
            ),
          ),
        ],
      ),
    );
  }
}

class ProgrammeEnrichmentPrototypeCard extends ConsumerWidget {
  const ProgrammeEnrichmentPrototypeCard({required this.request, super.key});

  final ProgrammeMetadataRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(programmeEnrichmentPrototypeProvider(request));
    return result.maybeWhen(
      data: (value) => value == null
          ? const SizedBox.shrink()
          : Card(
              child: ListTile(
                leading: value.posterUrl == null
                    ? null
                    : Semantics(
                        image: true,
                        label: 'Poster for ${value.title}',
                        child: SizedBox(
                          width: 56,
                          child: Image.network(
                            value.posterUrl.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.image_not_supported_outlined),
                          ),
                        ),
                      ),
                title: Text(value.title),
                subtitle: Text(
                  '${value.synopsis}\n'
                  '${_programmeMetadataLine(value)}'
                  '${value.attribution.notice} · '
                  '${value.attribution.providerName}',
                ),
                isThreeLine: true,
              ),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

String _programmeMetadataLine(ProgrammeEnrichment value) {
  final metadata = [
    if (value.year != null) value.year.toString(),
    if (value.rating != null) value.rating.toString(),
    if (value.genres.isNotEmpty) value.genres.join(', '),
  ];
  return metadata.isEmpty ? '' : '${metadata.join(' · ')}\n';
}

class SportsFixturesPrototypeShelf extends ConsumerWidget {
  const SportsFixturesPrototypeShelf({required this.request, super.key});

  final SportsFixturesRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(sportsFixturesPrototypeProvider(request));
    return result.maybeWhen(
      data: (value) {
        if (value == null || value.row.fixtures.isEmpty) {
          return const SizedBox.shrink();
        }
        return Semantics(
          container: true,
          label: '${value.row.title} sports fixtures',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.row.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final fixture in value.row.fixtures)
                ListTile(
                  title: Text(fixture.title),
                  subtitle: Text(
                    '${fixture.sport} · ${fixture.startsAt.toLocal()}',
                  ),
                ),
              Text(
                '${value.attribution.notice} · '
                '${value.attribution.providerName}',
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

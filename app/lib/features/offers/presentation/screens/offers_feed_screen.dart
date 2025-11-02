import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import '../widgets/offer_card.dart';
import '../../application/providers/offers_provider.dart';

/// Offers feed screen with Instagram-style cards
class OffersFeedScreen extends ConsumerWidget {
  const OffersFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(offersProvider);
    final savedOffers = ref.watch(savedOffersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loot'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Show search
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Show filters
            },
          ),
        ],
      ),
      body: offersAsync.when(
        data: (offers) {
          if (offers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No deals available',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index];
              final isSaved = savedOffers.contains(offer.id);

              return OfferCard(
                offer: offer,
                onSave: () {
                  final newSaved = {...savedOffers};
                  if (isSaved) {
                    newSaved.remove(offer.id);
                  } else {
                    newSaved.add(offer.id);
                  }
                  ref.read(savedOffersProvider.notifier).state = newSaved;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isSaved ? 'Removed from saved' : 'Added to saved',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                onShare: () {
                  share_plus.SharePlus.instance.share(
                    share_plus.ShareParams(
                      text:
                          '${offer.title}\n\n${offer.description}\n\n${offer.link}',
                      subject: offer.title,
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                'Error loading deals',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.refresh(offersProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ref.refresh(offersProvider);
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

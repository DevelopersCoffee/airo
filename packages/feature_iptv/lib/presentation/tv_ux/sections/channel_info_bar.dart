import 'package:flutter/material.dart';
import 'package:platform_channels/platform_channels.dart';

class ChannelInfoBar extends StatelessWidget {
  const ChannelInfoBar({super.key, this.channel});

  final IPTVChannel? channel;

  @override
  Widget build(BuildContext context) {
    final name = channel?.name ?? 'Choose a channel';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.live_tv),
          const SizedBox(width: 8),
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
          const Chip(label: Text('LIVE')),
          IconButton(
            onPressed: () {},
            tooltip: 'Favorite',
            icon: const Icon(Icons.favorite_border),
          ),
          IconButton(
            onPressed: () {},
            tooltip: 'Like',
            icon: const Icon(Icons.thumb_up_outlined),
          ),
          IconButton(
            onPressed: () {},
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            onPressed: () {},
            tooltip: 'Ways to watch',
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
    );
  }
}

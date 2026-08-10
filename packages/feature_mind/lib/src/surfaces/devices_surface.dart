import 'package:flutter/material.dart';

import '../runtime/mind_runtime.dart';
import '../runtime/models/mesh_models.dart';
import '../runtime/models/vault_models.dart';
import '../widgets/mind_palette.dart';
import '../widgets/relative_time.dart';
import 'mind_surface_scaffold.dart';

/// Surface 05. Pairing reads like a handshake between your own things: a
/// code, a fingerprint, a live/stale marker. Revoked devices stay listed as
/// evidence rather than vanishing.
class DevicesSurface extends StatefulWidget {
  const DevicesSurface({
    super.key,
    required this.runtime,
    required this.nowMs,
    this.onBack,
  });

  final MindRuntime runtime;

  /// The wall clock, supplied by the caller. No surface reads
  /// `DateTime.now()` itself — a golden that moves with wall time is a golden
  /// that gets deleted, and a real caller can pass the real clock at the
  /// point where it renders without that cost landing on every test.
  final int nowMs;

  final VoidCallback? onBack;

  @override
  State<DevicesSurface> createState() => _DevicesSurfaceState();
}

class _DevicesSurfaceState extends State<DevicesSurface> {
  late Future<_DevicesData> _data;
  PairingRequest? _pending;

  @override
  void initState() {
    super.initState();
    _data = _load();
    widget.runtime.mesh.pendingRequest().listen(
      (request) {
        if (mounted) setState(() => _pending = request);
      },
      // Pairing is a secondary feature of this screen; the authorised
      // devices list is driven by VaultPort and must still render if only
      // the mesh is unavailable. An unguarded stream error here would
      // otherwise crash the whole surface for a missing "nice to have".
      onError: (Object _) {
        if (mounted) setState(() => _pending = null);
      },
    );
  }

  Future<_DevicesData> _load() async {
    final vault = await widget.runtime.vault.state();
    final devices = await widget.runtime.vault.devices();
    final peers = await widget.runtime.mesh.peers().first;
    return _DevicesData(vault: vault, devices: devices, peers: peers);
  }

  Future<void> _authorise(PairingRequest request) async {
    await widget.runtime.mesh.authorise(request);
    if (mounted) setState(() => _pending = null);
  }

  Future<void> _deny(PairingRequest request) async {
    await widget.runtime.mesh.deny(request);
    if (mounted) setState(() => _pending = null);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DevicesData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          final failure = error is MindPortUnavailable
              ? error
              : MindPortUnavailable('MindRuntime', '$error');
          return MindSurfaceScaffold(
            title: 'DEVICES',
            status: MindSurfaceStatus.unavailable(failure.port, failure.reason),
            onBack: widget.onBack,
            child: const SizedBox.shrink(),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const MindSurfaceScaffold(
            title: 'DEVICES',
            status: MindSurfaceStatus.rebuilding(opsProcessed: 0, opsTotal: 0),
            child: SizedBox.shrink(),
          );
        }

        // Devices makes no ops/peer-count/vault claim of its own the way Home
        // does -- this screen IS the peer detail -- so the strip is
        // deliberately absent rather than repeating numbers this screen
        // already breaks out individually below.
        return MindSurfaceScaffold(
          title: 'DEVICES',
          status: const MindSurfaceStatus.live(
            opCount: 0,
            peerCount: 0,
            vaultSealed: true,
          ),
          onBack: widget.onBack,
          // A Column with the note pinned outside the scroll region, not the
          // ListView's last child. The design keeps this statement always
          // visible below the scrollable device list -- a SliverList only
          // builds what is near the viewport, so a fixed invariant placed as
          // the final list item can end up never built at all on a long list.
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  children: [
                    _MeshCard(peerCount: data.peers.length),
                    const SizedBox(height: 20),
                    const _SectionLabel('AUTHORISED DEVICES'),
                    for (final device in data.devices)
                      _DeviceRow(
                        device: device,
                        peer: _peerFor(device, data.peers),
                        nowMs: widget.nowMs,
                      ),
                    if (_pending != null) ...[
                      const SizedBox(height: 20),
                      _PendingCard(
                        request: _pending!,
                        onAuthorise: () => _authorise(_pending!),
                        onDeny: () => _deny(_pending!),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                child: Text(
                  'Revocation is O(contexts), never O(content) — a revoked '
                  'device loses every key at once.',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: MindPalette.ink.withValues(alpha: 0.4),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// A revoked or this-device entry has no meaningful peer record; only a
  /// remote, authorised device is looked up in the mesh.
  MindPeer? _peerFor(MindDevice device, List<MindPeer> peers) {
    if (device.isThisDevice || device.isRevoked) return null;
    for (final peer in peers) {
      if (peer.fingerprint == device.fingerprint) return peer;
    }
    return null;
  }
}

class _DevicesData {
  const _DevicesData({
    required this.vault,
    required this.devices,
    required this.peers,
  });

  final VaultState vault;
  final List<MindDevice> devices;
  final List<MindPeer> peers;
}

class _MeshCard extends StatelessWidget {
  const _MeshCard({required this.peerCount});

  final int peerCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: MindPalette.local.withValues(alpha: 0.4)),
        color: MindPalette.local.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lan_outlined,
                size: 18,
                color: MindPalette.local,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '_airomind._tcp · MDNS',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.8,
                    color: MindPalette.local,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$peerCount peers',
                style: TextStyle(
                  fontSize: 11,
                  color: MindPalette.ink.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Everything below syncs over your home network. Nothing is sent '
            "to a server, ours or anyone's.",
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: MindPalette.ink.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 2.2,
          color: MindPalette.ink.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.peer,
    required this.nowMs,
  });

  final MindDevice device;
  final MindPeer? peer;
  final int nowMs;

  bool get _isLive =>
      device.isThisDevice || peer?.liveness == PeerLiveness.live;

  /// "Live" covers this device and a peer seen just now. Anything else --
  /// stale, offline, or simply never having synced with this device -- shows
  /// its real elapsed time rather than a single flat "unavailable", because
  /// the design's whole point is that a person can tell how stale a device
  /// is, not just that it isn't live right now.
  String get _statusLabel {
    if (_isLive) return 'Live';
    final lastSeenMs = peer?.lastSeenMs;
    if (lastSeenMs == null) return 'unavailable';
    return relativeTime(lastSeenMs, nowMs);
  }

  static const _icons = {
    'Pixel 9 Pro': Icons.smartphone,
    'iPad Air · Studio': Icons.tablet_mac,
    'Fold 6 · Pocket': Icons.book_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final revoked = device.isRevoked;

    return Opacity(
      opacity: revoked ? 0.55 : 1,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: MindPalette.grid)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _icons[device.name] ?? Icons.laptop_mac,
                size: 24,
                color: MindPalette.ink,
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
                            device.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: MindPalette.ink,
                              decoration: revoked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (device.isThisDevice) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            color: MindPalette.ink,
                            child: const Text(
                              'THIS DEVICE',
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1,
                                color: MindPalette.onFilled,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (revoked)
                      Text(
                        'REVOKED ${relativeTime(device.revokedAtMs!, nowMs)} '
                        '· KEYS SHREDDED',
                        style: const TextStyle(
                          fontSize: 11,
                          letterSpacing: 1,
                          color: MindPalette.alarm,
                        ),
                      )
                    else
                      Text(
                        'key ${device.fingerprint}',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.5,
                          fontFamily: 'AiroCollapse',
                          color: MindPalette.ink.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
              if (!revoked)
                Text(
                  _statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: _isLive
                        ? MindPalette.local
                        : MindPalette.ink.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.request,
    required this.onAuthorise,
    required this.onDeny,
  });

  final PairingRequest request;
  final VoidCallback onAuthorise;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: MindPalette.remote.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PENDING AUTHORISATION',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              color: MindPalette.remote,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.watch_outlined,
                size: 24,
                color: MindPalette.ink,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.deviceName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: MindPalette.ink,
                      ),
                    ),
                    Text(
                      'Asking to join your vault',
                      style: TextStyle(
                        fontSize: 11,
                        color: MindPalette.ink.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              // The design spaces these digits with letter-spacing, not real
              // space characters -- a real space would make the six-digit
              // code unfindable as one string by anything that searches for
              // it (a test, an accessibility reader, a copy action).
              request.code,
              style: const TextStyle(
                fontFamily: 'AiroRulesExpanded',
                fontWeight: FontWeight.w700,
                fontSize: 26,
                letterSpacing: 6,
                color: MindPalette.ink,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onDeny,
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: MindPalette.ink.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text(
                      'DENY',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.8,
                        color: MindPalette.ink,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: onAuthorise,
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    color: MindPalette.ink,
                    child: const Text(
                      'AUTHORISE',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.8,
                        color: MindPalette.onFilled,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

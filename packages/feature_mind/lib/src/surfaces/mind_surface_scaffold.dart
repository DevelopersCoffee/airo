import 'package:flutter/material.dart';

import '../widgets/grouped_number.dart';
import '../widgets/mind_number_strip.dart';
import '../widgets/mind_palette.dart';
import '../widgets/mind_presence_pip.dart';

/// What a surface can currently tell a person about the runtime.
///
/// Three states, one type. A surface cannot render "unavailable" and a number
/// strip at the same time, because a strip reading "0 ops" when the truth is
/// "the log is not built yet" is a lie rather than an empty state.
@immutable
sealed class MindSurfaceStatus {
  const MindSurfaceStatus();

  /// The runtime answered.
  const factory MindSurfaceStatus.live({
    required int opCount,
    required int peerCount,
    required bool vaultSealed,
    bool isLocal,
    String? remoteLabel,
  }) = MindSurfaceLive;

  /// A sub-port this surface needs is not implemented yet.
  const factory MindSurfaceStatus.unavailable(String port, String reason) =
      MindSurfaceUnavailable;

  /// A projection is rebuilding. Carries progress, never a bare spinner.
  const factory MindSurfaceStatus.rebuilding({
    required int opsProcessed,
    required int opsTotal,
  }) = MindSurfaceRebuilding;
}

class MindSurfaceLive extends MindSurfaceStatus {
  const MindSurfaceLive({
    required this.opCount,
    required this.peerCount,
    required this.vaultSealed,
    this.isLocal = true,
    this.remoteLabel,
  });

  final int opCount;
  final int peerCount;
  final bool vaultSealed;
  final bool isLocal;
  final String? remoteLabel;
}

class MindSurfaceUnavailable extends MindSurfaceStatus {
  const MindSurfaceUnavailable(this.port, this.reason);

  final String port;
  final String reason;
}

class MindSurfaceRebuilding extends MindSurfaceStatus {
  const MindSurfaceRebuilding({
    required this.opsProcessed,
    required this.opsTotal,
  });

  final int opsProcessed;
  final int opsTotal;
}

/// The frame every Mind phone surface sits in.
///
/// Rules R01 and R04 are structural here rather than remembered per screen: a
/// surface built on this scaffold cannot ship without its presence pip or its
/// number strip, which is a stronger guarantee than a test that catches the
/// omission afterwards.
class MindSurfaceScaffold extends StatelessWidget {
  const MindSurfaceScaffold({
    super.key,
    required this.title,
    required this.status,
    required this.child,
    this.trailing,
    this.onBack,
  });

  final String title;
  final MindSurfaceStatus status;
  final Widget child;

  /// Actions for the title row — search, sync, a filter.
  final Widget? trailing;

  /// Null on a root surface, which has nowhere to go back to.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MindPalette.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusRow(status: status),
            _TitleRow(title: title, trailing: trailing, onBack: onBack),
            ..._body(),
          ],
        ),
      ),
    );
  }

  List<Widget> _body() {
    return switch (status) {
      MindSurfaceLive(:final opCount, :final peerCount, :final vaultSealed) => [
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: MindPalette.grid),
              bottom: BorderSide(color: MindPalette.grid),
            ),
          ),
          child: MindNumberStrip(
            opCount: opCount,
            peerCount: peerCount,
            vaultSealed: vaultSealed,
          ),
        ),
        Expanded(child: child),
      ],
      MindSurfaceUnavailable(:final port, :final reason) => [
        Expanded(
          child: _Unavailable(port: port, reason: reason),
        ),
      ],
      MindSurfaceRebuilding(:final opsProcessed, :final opsTotal) => [
        Expanded(
          child: _Rebuilding(processed: opsProcessed, total: opsTotal),
        ),
      ],
    };
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status});

  final MindSurfaceStatus status;

  @override
  Widget build(BuildContext context) {
    final live = status is MindSurfaceLive ? status as MindSurfaceLive : null;

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // Fixed, not a clock: a golden that moves with wall time is a
            // golden that gets deleted.
            const Text(
              '9:41',
              style: TextStyle(
                color: MindPalette.ink,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            MindPresencePip(
              isLocal: live?.isLocal ?? true,
              remoteLabel: live?.remoteLabel,
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.title,
    required this.trailing,
    required this.onBack,
  });

  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: EdgeInsets.only(left: onBack == null ? 18 : 4, right: 12),
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: MindPalette.ink),
                tooltip: 'Back',
              ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: MindPalette.ink,
                  fontFamily: 'AiroRulesExpanded',
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  letterSpacing: 2,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.port, required this.reason});

  final String port;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NOT BUILT YET',
              style: TextStyle(
                color: MindPalette.remote,
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            // Names the port, so a person learns the rest of the app works.
            Text(
              '$port — $reason',
              style: const TextStyle(
                color: MindPalette.ink,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rebuilding extends StatelessWidget {
  const _Rebuilding({required this.processed, required this.total});

  final int processed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : processed / total;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'REBUILDING PROJECTION',
              style: TextStyle(
                color: MindPalette.local,
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            // A number, not a spinner: it tells a person whether to wait.
            Text(
              '${groupedNumber(processed)} of ${groupedNumber(total)} ops',
              style: const TextStyle(color: MindPalette.ink, fontSize: 14),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: fraction,
                backgroundColor: MindPalette.grid,
                valueColor: const AlwaysStoppedAnimation(MindPalette.local),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

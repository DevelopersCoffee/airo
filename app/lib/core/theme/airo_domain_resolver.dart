import 'package:core_ui/core_ui.dart';

/// Resolves the active product mood from the canonical route.
///
/// Unknown and cross-cutting routes intentionally fall back to Airo's neutral
/// identity rather than guessing from presentation state.
AiroDomain airoDomainForLocation(String location) {
  final path = Uri.parse(location).path;

  if (path == '/home' || path.startsWith('/airo')) return AiroDomain.airo;
  if (path.startsWith('/money') || path.startsWith('/vault')) {
    return AiroDomain.money;
  }
  if (path.startsWith('/assistant') || path.startsWith('/agent')) {
    return AiroDomain.mind;
  }
  if (path.startsWith('/music') || path.startsWith('/beats')) {
    return AiroDomain.beats;
  }
  if (path.startsWith('/iptv') ||
      path.startsWith('/vod') ||
      path.startsWith('/guide') ||
      path.startsWith('/favorites') ||
      path.startsWith('/live')) {
    return AiroDomain.live;
  }
  if (path.startsWith('/games') || path.startsWith('/arena')) {
    return AiroDomain.arena;
  }
  if (path.startsWith('/quest') || path.startsWith('/life-track')) {
    return AiroDomain.quest;
  }
  if (path.startsWith('/reader')) return AiroDomain.reader;

  return AiroDomain.neutral;
}

import 'package:platform_channels/channel_search.dart';

import 'm3u_parser_service.dart' show parseM3UChannels;

/// Parse M3U content into normalized, deduplicated IPTV channels using the
/// shared pure-Dart fallback parser (single implementation in
/// `core_native.parseM3uEntries`).
///
/// This intentionally stays on the synchronous Dart path — it never touches
/// the Rust FFI bridge — so host-only benchmark tools keep working in
/// environments without the compiled `airo_core` native library. Production
/// imports on native platforms parse through Rust; see
/// `M3UParserService.parseM3UOffMain`.
List<IPTVChannel> parseM3UDartChannels(String content) =>
    parseM3UChannels(content);

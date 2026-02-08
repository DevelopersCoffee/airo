/// IPTV Feature - YouTube-quality streaming experience
///
/// Features:
/// - Adaptive bitrate streaming (ABR)
/// - Video buffering with 10-30 second preloading
/// - Smooth playback with minimal stuttering
/// - Fast initial load (<2 seconds target)
/// - Seamless quality switching
/// - Network interruption handling with auto-retry
/// - Background audio for music channels
/// - YouTube-like playback controls

// Models
export 'domain/models/iptv_channel.dart';
export 'domain/models/streaming_state.dart';

// Services
export 'domain/services/iptv_streaming_service.dart';
export 'domain/services/video_player_streaming_service.dart';
export 'domain/services/m3u_parser_service.dart';

// Providers
export 'application/providers/iptv_providers.dart';

// Screens
export 'presentation/screens/iptv_screen.dart';

// Widgets
export 'presentation/widgets/video_player_widget.dart';
export 'presentation/widgets/channel_list_widget.dart';
export 'presentation/widgets/iptv_mini_player.dart';

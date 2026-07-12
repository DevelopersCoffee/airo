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
/// - Live DVR with Go Live functionality
library;

export 'package:platform_channels/platform_channels.dart';
export 'package:platform_history/platform_history.dart';
export 'package:platform_media/platform_media.dart';
export 'package:platform_player/platform_player.dart';
export 'package:platform_playlist_import/platform_playlist_import.dart';
export 'package:platform_streams/platform_streams.dart';

// Providers
export '../application/providers/iptv_providers.dart';

// Screens
export '../presentation/screens/iptv_screen.dart';

// Widgets
export '../presentation/widgets/channel_list_widget.dart';
export '../presentation/widgets/cast_device_picker_sheet.dart';
export '../presentation/widgets/go_live_button.dart';
export '../presentation/widgets/iptv_cast_mini_controller.dart';
export '../presentation/widgets/iptv_mini_player.dart';
export '../presentation/widgets/live_indicators.dart';
export '../presentation/widgets/video_player_widget.dart';

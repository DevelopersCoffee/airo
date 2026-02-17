/// TV support utilities for Android TV and Fire TV
///
/// This library provides:
/// - D-pad input handling for remote control navigation
/// - Focus management for TV UI
/// - TV-specific UI components and dimensions
/// - Visual focus indicators
/// - Fire TV specific support (voice button, channel up/down, safe zones)
///
/// ## Key Components
///
/// ### Input Handling
/// - [TvInputHandler] - Intercepts D-pad and remote control input
/// - [TvInputKey] - Enum of TV input keys (includes Fire TV specific keys)
///
/// ### Focus Management
/// - [TvFocusManager] - Central focus state management
/// - [TvFocusable] - Makes any widget focusable with visual indicators
/// - [TvFocusConstants] - Standard focus styling constants
/// - [TvFocusWrapConfig] - Focus wrap-around behavior configuration
///
/// ### Navigation Hints
/// - [TvNavigationHints] - Standard hint messages
/// - [TvNavigationHintWidget] - Widget to display hints
///
/// ### Providers
/// - [isTvModeProvider] - Check if running on TV
/// - [tvDimensionsProvider] - Get TV-specific dimensions
/// - [tvDimensionsWithFireTvProvider] - Dimensions with Fire TV safe zones
///
/// ## Fire TV Support
///
/// Fire TV specific features:
/// - Voice search button mapping (`TvInputKey.voiceSearch`)
/// - Channel up/down buttons (`TvInputKey.channelUp`, `TvInputKey.channelDown`)
/// - Safe zone padding via `TvUiDimensions.fireTv()`
/// - Platform detection via `DeviceFormFactorDetector.isFireTv()`
///
/// ## Usage Example
///
/// ```dart
/// import 'package:app/core/tv/tv.dart';
///
/// // Check if running on TV
/// if (ref.watch(isTvModeProvider(context))) {
///   // Render TV UI
/// }
///
/// // Wrap focusable items
/// TvFocusable(
///   onSelect: () => playChannel(channel),
///   child: ChannelCard(channel: channel),
/// )
///
/// // Handle Fire TV specific input
/// TvInputHandler(
///   onInput: (key) {
///     if (key == TvInputKey.voiceSearch) {
///       // Launch voice search
///     }
///     if (key.isChannelKey) {
///       // Handle channel up/down
///     }
///   },
///   child: YourWidget(),
/// )
/// ```
///
/// ## Voice Search (M6)
///
/// Voice search integration for Fire TV:
/// - [VoiceSearchService] - Abstract interface for voice search
/// - [VoiceSearchState] - Enum of voice search states (idle, listening, processing, completed, error)
/// - [VoiceSearchResult] - Result of voice search operation
/// - [MockVoiceSearchService] - Mock implementation for testing
/// - [VoiceSearchOverlay] - Full-screen overlay for voice search UI
/// - [TvChannelGridWithVoiceSearch] - Channel grid with integrated voice search
/// - [TvVoiceSearchMixin] - Mixin for adding voice search to any TV widget
///
/// ### Voice Search Example
///
/// ```dart
/// // Using TvChannelGridWithVoiceSearch
/// TvChannelGridWithVoiceSearch(
///   onChannelSelect: (channel) => playChannel(channel),
/// )
///
/// // Using TvVoiceSearchMixin
/// class MyTvWidget extends ConsumerStatefulWidget { ... }
///
/// class _MyTvWidgetState extends ConsumerState<MyTvWidget>
///     with TvVoiceSearchMixin {
///   TvInputResult _handleInput(TvInputKey key) {
///     if (handleVoiceSearchInput(key)) {
///       return TvInputResult.handled;
///     }
///     return TvInputResult.notHandled;
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return buildWithVoiceSearch(
///       context,
///       child: TvInputHandler(
///         onInput: _handleInput,
///         child: MyContent(),
///       ),
///     );
///   }
/// }
/// ```
library;

export 'tv_focus_manager.dart';
export 'tv_focusable.dart';
export 'tv_input_handler.dart';
export 'tv_providers.dart';

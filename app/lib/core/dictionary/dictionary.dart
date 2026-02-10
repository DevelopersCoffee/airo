/// Dictionary framework - Word definitions with audio pronunciation
///
/// This framework provides word lookup functionality using the Free Dictionary API.
///
/// Features:
/// - Word definitions with phonetic pronunciation
/// - Audio pronunciation playback
/// - Synonyms and antonyms
/// - Etymology/origin information
/// - Context menu integration for text selection
///
/// Usage:
/// ```dart
/// // Show dictionary popup
/// DictionaryPopup.show(context, 'hello');
///
/// // Use SelectableText with dictionary
/// SelectableTextWithDictionary('Select any word to look it up')
///
/// // Use Text with dictionary (long press)
library;

/// TextWithDictionary('Long press any word')
///
/// // Use extensions
/// Text('Hello world').withDictionary()
/// SelectableText('Hello world').withDictionary()
///
/// // Direct API usage
/// final service = DictionaryService();
/// final entries = await service.lookupWord('hello');
/// ```

export 'models/dictionary_entry.dart';
export 'services/dictionary_service.dart';
export 'widgets/dictionary_popup.dart';
export 'widgets/selectable_text_with_dictionary.dart';
export 'widgets/dictionary_text_wrapper.dart';
export 'screens/dictionary_demo_screen.dart';

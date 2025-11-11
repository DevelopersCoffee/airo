import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/dictionary_entry.dart';
import '../services/dictionary_service.dart';

/// Popup widget to display word definition
class DictionaryPopup extends StatefulWidget {
  final String word;
  final VoidCallback? onClose;

  const DictionaryPopup({
    super.key,
    required this.word,
    this.onClose,
  });

  @override
  State<DictionaryPopup> createState() => _DictionaryPopupState();

  /// Show dictionary popup as a dialog
  static Future<void> show(BuildContext context, String word) {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: DictionaryPopup(
            word: word,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  /// Show dictionary popup as a bottom sheet (better for mobile)
  static Future<void> showBottomSheet(BuildContext context, String word) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => DictionaryPopup(
          word: word,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

class _DictionaryPopupState extends State<DictionaryPopup> {
  final DictionaryService _dictionaryService = DictionaryService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<DictionaryEntry>? _entries;
  bool _isLoading = true;
  String? _error;
  int _selectedEntryIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDefinition();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadDefinition() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final entries = await _dictionaryService.lookupWord(widget.word);
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } on DictionaryNotFoundException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } on DictionaryServiceException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'An unexpected error occurred';
        _isLoading = false;
      });
    }
  }

  Future<void> _playAudio(String audioUrl) async {
    try {
      await _audioPlayer.play(UrlSource(audioUrl));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to play audio')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.book),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Dictionary',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : _buildContent(),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadDefinition,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_entries == null || _entries!.isEmpty) {
      return const Center(child: Text('No definitions found'));
    }

    final entry = _entries![_selectedEntryIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word and phonetic
          _buildWordHeader(entry),
          const SizedBox(height: 24),

          // Origin
          if (entry.origin != null) ...[
            _buildOrigin(entry.origin!),
            const SizedBox(height: 24),
          ],

          // Meanings
          ...entry.meanings.map((meaning) => _buildMeaning(meaning)),
        ],
      ),
    );
  }

  Widget _buildWordHeader(DictionaryEntry entry) {
    final theme = Theme.of(context);
    final audioPhonetic = entry.phonetics.firstWhere(
      (p) => p.hasAudio,
      orElse: () => entry.phonetics.isNotEmpty
          ? entry.phonetics.first
          : const Phonetic(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                entry.word,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            if (audioPhonetic.hasAudio)
              IconButton.filled(
                onPressed: () => _playAudio(audioPhonetic.audioUrl!),
                icon: const Icon(Icons.volume_up),
                tooltip: 'Play pronunciation',
              ),
          ],
        ),
        if (entry.phonetic != null || audioPhonetic.text != null) ...[
          const SizedBox(height: 8),
          Text(
            entry.phonetic ?? audioPhonetic.text ?? '',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOrigin(String origin) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_edu,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Origin',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(origin, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildMeaning(Meaning meaning) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Part of speech
          Chip(
            label: Text(meaning.partOfSpeech),
            backgroundColor: theme.colorScheme.secondaryContainer,
          ),
          const SizedBox(height: 12),

          // Definitions
          ...meaning.definitions.asMap().entries.map((entry) {
            final index = entry.key;
            final definition = entry.value;
            return _buildDefinition(index + 1, definition);
          }),
        ],
      ),
    );
  }

  Widget _buildDefinition(int number, Definition definition) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Definition
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$number. ',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  definition.definition,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),

          // Example
          if (definition.hasExample) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                '"${definition.example}"',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],

          // Synonyms
          if (definition.hasSynonyms) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'Synonyms:',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  ...definition.synonyms.map(
                    (synonym) => Chip(
                      label: Text(synonym),
                      labelStyle: theme.textTheme.labelSmall,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}


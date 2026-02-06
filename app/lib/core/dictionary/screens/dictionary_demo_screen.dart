import 'package:flutter/material.dart';
import '../dictionary.dart';

/// Demo screen showcasing dictionary features
class DictionaryDemoScreen extends StatelessWidget {
  const DictionaryDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictionary Demo'),
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.menu_book,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Dictionary Framework',
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Look up word definitions with audio pronunciation using the Free Dictionary API',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Feature 1: SelectableText with Dictionary
            Text(
              '1. SelectableText with Dictionary',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Select any word and choose "Look up" from the context menu:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: SelectableTextWithDictionary(
                  'The serendipitous discovery of penicillin revolutionized medicine. '
                  'This fortuitous event demonstrated how perspicacious observation '
                  'can lead to extraordinary breakthroughs.',
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Feature 2: Text with Dictionary (Long Press)
            Text(
              '2. Text with Dictionary (Long Press)',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Long press on the text to select a word:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: TextWithDictionary(
                  'Ephemeral moments of tranquility',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Feature 3: Quick Lookup Buttons
            Text('3. Quick Lookup Examples', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Tap any word to see its definition:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildWordChip(context, 'hello', Icons.waving_hand),
                _buildWordChip(context, 'serendipity', Icons.auto_awesome),
                _buildWordChip(context, 'ephemeral', Icons.access_time),
                _buildWordChip(context, 'perspicacious', Icons.visibility),
                _buildWordChip(context, 'ubiquitous', Icons.public),
                _buildWordChip(context, 'eloquent', Icons.record_voice_over),
                _buildWordChip(context, 'resilient', Icons.fitness_center),
                _buildWordChip(context, 'paradigm', Icons.lightbulb),
                _buildWordChip(context, 'innovation', Icons.rocket_launch),
                _buildWordChip(context, 'magnificent', Icons.star),
              ],
            ),

            const SizedBox(height: 24),

            // Feature 4: Extension Methods
            Text('4. Extension Methods', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Use .withDictionary() extension on any Text or SelectableText:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Code Example:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const SelectableText(
                        'Text("Hello world").withDictionary()\n'
                        'SelectableText("Hello").withDictionary()',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.greenAccent,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Result (long press):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Extraordinary accomplishment',
                      style: TextStyle(fontSize: 16),
                    ).withDictionary(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Features List
            Text('Features', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _buildFeatureItem(
              Icons.volume_up,
              'Audio Pronunciation',
              'Listen to correct pronunciation with native audio',
            ),
            _buildFeatureItem(
              Icons.text_fields,
              'Phonetic Spelling',
              'See phonetic transcription for proper pronunciation',
            ),
            _buildFeatureItem(
              Icons.library_books,
              'Multiple Definitions',
              'View all meanings across different parts of speech',
            ),
            _buildFeatureItem(
              Icons.format_quote,
              'Usage Examples',
              'See words used in context with real examples',
            ),
            _buildFeatureItem(
              Icons.compare_arrows,
              'Synonyms & Antonyms',
              'Discover related and opposite words',
            ),
            _buildFeatureItem(
              Icons.history_edu,
              'Etymology',
              'Learn the origin and history of words',
            ),
            _buildFeatureItem(
              Icons.offline_bolt,
              'Free API',
              'No API key required - completely free to use',
            ),

            const SizedBox(height: 24),

            // API Info
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Powered by Free Dictionary API',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'https://dictionaryapi.dev/',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWordChip(BuildContext context, String word, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(word),
      onPressed: () => DictionaryPopup.showBottomSheet(context, word),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

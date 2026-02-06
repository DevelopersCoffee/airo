import 'package:flutter/material.dart';
import '../http_status.dart';
import '../widgets/http_dog_image.dart';

/// Fun reference screen showing all HTTP status codes with dog images
class HttpStatusReferenceScreen extends StatefulWidget {
  const HttpStatusReferenceScreen({super.key});

  @override
  State<HttpStatusReferenceScreen> createState() =>
      _HttpStatusReferenceScreenState();
}

class _HttpStatusReferenceScreenState extends State<HttpStatusReferenceScreen> {
  HttpStatusCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statuses = _selectedCategory == null
        ? HttpStatusCodes.allStatuses
        : HttpStatusCodes.getByCategory(_selectedCategory!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('HTTP Status Dogs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfo(context),
            tooltip: 'About',
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildCategoryChip(
                  context,
                  label: 'All',
                  category: null,
                  icon: Icons.pets,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  context,
                  label: '1xx Info',
                  category: HttpStatusCategory.informational,
                  icon: Icons.info,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  context,
                  label: '2xx Success',
                  category: HttpStatusCategory.success,
                  icon: Icons.check_circle,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  context,
                  label: '3xx Redirect',
                  category: HttpStatusCategory.redirection,
                  icon: Icons.arrow_forward,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  context,
                  label: '4xx Client',
                  category: HttpStatusCategory.clientError,
                  icon: Icons.error,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  context,
                  label: '5xx Server',
                  category: HttpStatusCategory.serverError,
                  icon: Icons.warning,
                ),
              ],
            ),
          ),

          // Status grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _getCrossAxisCount(context),
                childAspectRatio: 0.75,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: statuses.length,
              itemBuilder: (context, index) {
                final status = statuses[index];
                return HttpDogCard(
                  statusCode: status.code,
                  title: status.message,
                  subtitle: status.description,
                  onTap: () => _showStatusDetail(context, status),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
    BuildContext context, {
    required String label,
    required HttpStatusCategory? category,
    required IconData icon,
  }) {
    final isSelected = _selectedCategory == category;
    final theme = Theme.of(context);

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(label)],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = selected ? category : null;
        });
      },
      selectedColor: theme.colorScheme.primaryContainer,
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 600) return 2;
    return 1;
  }

  void _showStatusDetail(BuildContext context, HttpStatus status) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HttpDogImage(
                  statusCode: status.code,
                  width: 300,
                  height: 300,
                  showStatusText: false,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HttpDogIndicator(statusCode: status.code),
                    const SizedBox(width: 12),
                    Text(
                      status.message,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  status.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pets),
            SizedBox(width: 8),
            Text('HTTP Status Dogs'),
          ],
        ),
        content: const Text(
          'HTTP status codes visualized with adorable dog images from http.dog!\n\n'
          'This framework-level feature displays HTTP status codes throughout the app '
          'to make error handling more fun and user-friendly.\n\n'
          '🐕 1xx: Informational responses\n'
          '🐕 2xx: Successful responses\n'
          '🐕 3xx: Redirection messages\n'
          '🐕 4xx: Client error responses\n'
          '🐕 5xx: Server error responses',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

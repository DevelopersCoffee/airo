import '../contracts/log_filter.dart';
import '../events/log_entry.dart';
import '../levels/log_category.dart';

class CategoryFilter implements LogFilter {
  final Set<LogCategory> allowedCategories;

  const CategoryFilter(this.allowedCategories);

  @override
  bool shouldLog(LogEntry entry) {
    return allowedCategories.contains(entry.category);
  }
}

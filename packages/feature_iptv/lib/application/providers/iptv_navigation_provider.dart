import 'package:flutter_riverpod/flutter_riverpod.dart';

enum IptvNavigationTab { home, stream }

final iptvNavigationTabProvider = StateProvider<int>(
  (ref) => IptvNavigationTab.home.index,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

enum IptvNavigationTab { home, stream }

final iptvNavigationTabProvider = StateProvider<int>(
  (ref) => IptvNavigationTab.home.index,
);

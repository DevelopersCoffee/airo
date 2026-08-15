import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_assistant_host_adapter.dart';

/// Mind-shell host adapter: model management lives on `/models`, not Settings.
class MindAssistantHostAdapter extends AppAssistantHostAdapter {
  const MindAssistantHostAdapter(super.ref);

  @override
  void openModelManager(BuildContext context) => context.push('/models');

  @override
  void openHostSettings(BuildContext context) {
    // IPTV settings hub is not shipped in Mind; send people to model prefs.
    openModelManager(context);
  }
}

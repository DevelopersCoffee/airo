import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bootstrap/app_bootstrap.dart';
import 'shell/app_shell.dart';

class ApplicationHost extends StatefulWidget {
  const ApplicationHost({super.key});

  @override
  State<ApplicationHost> createState() => _ApplicationHostState();
}

class _ApplicationHostState extends State<ApplicationHost> {
  final ProviderContainer _container = ProviderContainer();

  @override
  void initState() {
    super.initState();
    _startBootstrap();
  }

  Future<void> _startBootstrap() async {
    final bootstrap = AppBootstrap(_container);
    await bootstrap.execute();
  }

  @override
  void dispose() {
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: _container,
      child: const AppShell(),
    );
  }
}

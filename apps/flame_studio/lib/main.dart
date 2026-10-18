import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const FlameStudioApp());
}

/// The Flame Studio desktop app. Placeholder until the app shell
/// (v0.1 work item 1).
class FlameStudioApp extends StatelessWidget {
  const FlameStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flame Studio',
      theme: FsTheme.dark(),
      home: const Scaffold(body: Center(child: Text('Flame Studio'))),
    );
  }
}

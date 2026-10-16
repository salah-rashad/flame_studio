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
    return const MaterialApp(
      title: 'Flame Studio',
      home: Scaffold(body: Center(child: Text('Flame Studio'))),
    );
  }
}

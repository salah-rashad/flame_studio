import 'package:flutter/material.dart';
import 'package:pyro_ui/pyro_ui.dart';

void main() {
  runApp(const PyroApp());
}

/// The Pyro desktop app. Placeholder until the app shell
/// (v0.1 work item 1).
class PyroApp extends StatelessWidget {
  const PyroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pyro',
      theme: PrTheme.dark(),
      home: const Scaffold(body: Center(child: Text('Pyro'))),
    );
  }
}

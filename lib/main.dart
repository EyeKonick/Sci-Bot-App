import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(
    const ProviderScope(
      child: SCIBotApp(),
    ),
  );
}

class SCIBotApp extends StatelessWidget {
  const SCIBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCI-Bot',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'SCI-Bot - Phase 1 Setup Complete',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

class GameHubScreen extends StatelessWidget {
  const GameHubScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jeux')),
      body: const Center(child: Text('Page Jeux/GameHub - À implémenter')),
    );
  }
}

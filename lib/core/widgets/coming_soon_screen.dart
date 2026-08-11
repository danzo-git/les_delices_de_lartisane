import 'package:flutter/material.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bientôt disponible'),
      ),
      body: const Center(
        child: Text(
          'Cette fonctionnalité sera bientôt disponible.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

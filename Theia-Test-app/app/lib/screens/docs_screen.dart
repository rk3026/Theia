import 'package:flutter/material.dart';

class DocsScreen extends StatelessWidget {
  const DocsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Docs & Traceability'),
      ),
      body: const Center(
        child: Text('Traceability references coming soon'),
      ),
    );
  }
}

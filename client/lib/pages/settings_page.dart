import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../providers/history_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _Section(title: 'API', children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Server'),
              subtitle: Text(AppConfig.apiBaseUrl),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Version'),
              subtitle: const Text('v0.1.0-mvp'),
            ),
          ]),
          _Section(title: 'Data', children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Clear Cache'),
              onTap: () {
                ref.read(historyProvider.notifier).clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache cleared')),
                );
              },
            ),
          ]),
          _Section(title: 'About', children: [
            const ListTile(
              leading: Icon(Icons.code),
              title: Text('code2offer'),
              subtitle: Text('AI Algorithm Interview Coach\nBuilt with Flutter + FastAPI + DeepSeek'),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
        ),
        ...children,
        const Divider(),
      ],
    );
  }
}

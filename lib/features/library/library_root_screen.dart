import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LibraryRootScreen extends StatelessWidget {
  const LibraryRootScreen({super.key});

  static const _groups = [
    'Chest',
    'Back',
    'Shoulders',
    'Biceps',
    'Triceps',
    'Legs',
    'Abs',
    'Calves',
    'Stretching',
    'Full Body',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _groups.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final group = _groups[index];
          return ListTile(
            title: Text(group),
            onTap: () => context.push('/library/group/${_slug(group)}'),
          );
        },
      ),
    );
  }

  String _slug(String value) => value.toLowerCase().replaceAll(' ', '-');
}

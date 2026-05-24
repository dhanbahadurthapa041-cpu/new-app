import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../widgets/glass_panel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _schoolController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final schoolName = await StorageService.loadSchoolName();
    if (!mounted) return;
    setState(() {
      _schoolController.text = schoolName;
      _isLoading = false;
    });
  }

  Future<void> _saveSchoolName() async {
    final name = _schoolController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('School name cannot be empty.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });
    await StorageService.saveSchoolName(name);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('School name updated.')));
  }

  Future<void> _clearData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This removes the school setup, classes, rosters, and saved attendance from this device. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await StorageService.clearAllAppData();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _backgroundGradient(context),
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'School Profile',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _schoolController,
                            decoration: const InputDecoration(
                              labelText: 'School Name',
                              prefixIcon: Icon(Icons.school_outlined),
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _isSaving ? null : _saveSchoolName,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save Name'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Data',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Clear local data when you want to set up the app again from a blank state.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _clearData,
                            icon: const Icon(Icons.delete_forever_outlined),
                            label: const Text('Clear All Data'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  List<Color> _backgroundGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const [Color(0xFF0F172A), Color(0xFF111827), Color(0xFF0B1120)]
        : const [Color(0xFFF8FAFC), Color(0xFFEFF6FF), Color(0xFFF8FAFC)];
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/preferences_service.dart';
import '../services/voice_service.dart';
import 'emergency_contacts_screen.dart';
import 'favorites_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final PreferencesService _preferencesService;
  final VoiceService _voiceService = VoiceService();
  bool _voiceReady = false;
  bool _testingVoice = false;
  final DateFormat _timestampFormat = DateFormat('MMMM d, yyyy h:mm a');

  @override
  void initState() {
    super.initState();
    _preferencesService = context.read<PreferencesService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeVoice());
    });
  }

  Future<void> _initializeVoice() async {
    await _voiceService.init();
    await _voiceService.setVolume(_preferencesService.ttsVolume);
    if (mounted) {
      setState(() {
        _voiceReady = true;
      });
    }
  }

  Future<void> _handleTestVoice() async {
    if (!_voiceReady || _testingVoice) {
      return;
    }
    setState(() {
      _testingVoice = true;
    });
    await _voiceService.speak('Current voice volume.');
    if (mounted) {
      setState(() {
        _testingVoice = false;
      });
    }
  }

  @override
  void dispose() {
    unawaited(_voiceService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>().current;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caretaker Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Audio & Feedback'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Text-to-Speech Volume',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: prefs.ttsVolume,
                    min: 0.2,
                    max: 1.0,
                    divisions: 8,
                    label: prefs.ttsVolume.toStringAsFixed(1),
                    onChanged: (value) {
                      _preferencesService.setTtsVolume(value);
                      unawaited(_voiceService.setVolume(value));
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _voiceReady ? _handleTestVoice : null,
                      icon: _testingVoice
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.volume_up),
                      label: const Text('Test Voice'),
                    ),
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    title: const Text('Enable Haptic Feedback'),
                    subtitle: const Text('Vibrate when confirming navigation commands.'),
                    value: prefs.hapticsEnabled,
                    onChanged: (value) {
                      _preferencesService.setHapticsEnabled(value);
                      _acknowledgeUpdate('Haptics ${value ? 'enabled' : 'disabled'}');
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Accessibility Preferences'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Avoid Stairs'),
                  subtitle: const Text('Route planning will prefer elevators and ramps.'),
                  value: prefs.avoidStairs,
                  onChanged: (value) {
                    _preferencesService.setAvoidStairs(value);
                    _acknowledgeUpdate('Avoid stairs ${value ? 'enabled' : 'disabled'}');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Caretaker Tools'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.people_alt_outlined),
                  title: const Text('Emergency Contacts'),
                  subtitle: const Text('Add, edit, and manage emergency contacts'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()),
                    );
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.star_outline),
                  title: const Text('Favorite Destinations'),
                  subtitle: const Text('Create and reorder quick access destinations'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: Text(
              'Last updated ${_timestampFormat.format(prefs.updatedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade700,
            ),
      ),
    );
  }

  void _acknowledgeUpdate(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    if (_voiceReady) {
      _voiceService.speak(message);
    }
  }
}

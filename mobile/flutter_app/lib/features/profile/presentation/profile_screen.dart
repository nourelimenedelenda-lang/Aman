import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../location/domain/repositories/location_repository.dart';
import '../../profile/domain/entities/emergency_contact.dart';
import '../../profile/domain/entities/profile_settings.dart';
import '../domain/repositories/profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.repository,
    required this.locations,
    required this.onLocationAccessChanged,
    this.accountName,
    this.accountEmail,
    this.onSignOut,
  });

  final ProfileRepository repository;
  final LocationRepository locations;
  final VoidCallback onLocationAccessChanged;
  final String? accountName;
  final String? accountEmail;
  final Future<void> Function()? onSignOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  late Future<ProfileSettings> _settingsFuture;
  ProfileSettings? _settings;
  LocationAccessStatus? _locationAccess;
  String? _locationError;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsFuture = widget.repository.getSettings();
    unawaited(_refreshLocationAccess());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshLocationAccess());
    }
  }

  Future<void> _refreshLocationAccess() async {
    try {
      final status = await widget.locations.getAccessStatus();
      if (mounted) {
        setState(() {
          _locationAccess = status;
          _locationError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _locationError = 'Unable to check location access: $error',
        );
      }
    }
  }

  Future<void> _manageLocationAccess() async {
    try {
      final status =
          _locationAccess ?? await widget.locations.getAccessStatus();
      final nextStatus = switch (status) {
        LocationAccessStatus.permanentlyDenied => await _openSettings(
          widget.locations.openAppSettings,
        ),
        LocationAccessStatus.servicesDisabled => await _openSettings(
          widget.locations.openLocationSettings,
        ),
        LocationAccessStatus.granted => status,
        LocationAccessStatus.denied => await widget.locations.requestAccess(),
      };
      if (!mounted) return;
      setState(() {
        _locationAccess = nextStatus;
        _locationError = null;
      });
      if (nextStatus == LocationAccessStatus.granted) {
        widget.onLocationAccessChanged();
      } else if (nextStatus == LocationAccessStatus.denied) {
        _showMessage('Location access was not granted.');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _locationError = 'Unable to update location access: $error',
        );
      }
    }
  }

  Future<LocationAccessStatus> _openSettings(
    Future<bool> Function() openSettings,
  ) async {
    final opened = await openSettings();
    if (!opened) {
      throw StateError('The device could not open the required settings page.');
    }
    return widget.locations.getAccessStatus();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showInformation(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _update(ProfileSettings settings) async {
    final previous = _settings;
    setState(() {
      _settings = settings;
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveSettings(settings);
    } catch (error) {
      if (mounted) {
        setState(() {
          _settings = previous;
          _error = 'Unable to save profile settings: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileSettings>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load profile settings: ${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        _settings ??= snapshot.data;
        final settings = _settings!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 28),
          children: [
            const Text(
              'YOUR ACCOUNT',
              style: TextStyle(
                color: AppColors.orange,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Profile & settings',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 17),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    child: Text(
                      (widget.accountName ?? 'AM')
                          .trim()
                          .split(RegExp(r'\s+'))
                          .where((part) => part.isNotEmpty)
                          .take(2)
                          .map((part) => part[0].toUpperCase())
                          .join(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.accountName?.isNotEmpty == true
                              ? widget.accountName!
                              : 'ResQRoad account',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.accountEmail ?? 'Signed in on this device',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Profile details',
                    color: Colors.white,
                    onPressed: () => _showInformation(
                      'Profile details',
                      '${widget.accountName ?? 'ResQRoad account'}\n${widget.accountEmail ?? ''}',
                    ),
                    icon: Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Emergency contacts',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addContact(settings),
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Add'),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'The first contact is primary and opens in the phone dialer if an accident countdown expires.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
            _CardColumn(
              children: settings.contacts.isEmpty
                  ? const [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No emergency contacts saved on this device.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ]
                  : settings.contacts
                        .map(
                          (contact) => ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.orangeSoft,
                              child: Icon(
                                Icons.person_outline,
                                color: AppColors.orange,
                              ),
                            ),
                            title: Text(contact.name),
                            subtitle: Text(
                              '${contact.relationship} · ${contact.phone}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove ${contact.name}',
                              onPressed: () => _update(
                                settings.copyWith(
                                  contacts: settings.contacts
                                      .where((item) => item != contact)
                                      .toList(),
                                ),
                              ),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        )
                        .toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              'Safety preferences',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 9),
            _CardColumn(
              children: [
                _Setting(
                  title: 'Accident detection',
                  subtitle:
                      'Prototype toggle only; no background detection runs.',
                  value: settings.accidentDetection,
                  onChanged: (value) =>
                      _update(settings.copyWith(accidentDetection: value)),
                ),
                _Setting(
                  title: 'Notifications',
                  subtitle: 'Updates and local reminders',
                  value: settings.notifications,
                  onChanged: (value) =>
                      _update(settings.copyWith(notifications: value)),
                ),
                _Setting(
                  title: 'Impact sound support',
                  subtitle: 'Microphone access is not implemented.',
                  value: settings.impactSound,
                  onChanged: (value) =>
                      _update(settings.copyWith(impactSound: value)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'App settings',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 9),
            _CardColumn(
              children: [
                _SettingsMenuTile(
                  icon: Icons.location_on_outlined,
                  title: 'Location permissions',
                  subtitle:
                      _locationError ?? _locationStatusLabel(_locationAccess),
                  onTap: _manageLocationAccess,
                  trailing: _locationAccess == null && _locationError == null
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
                _SettingsMenuTile(
                  icon: Icons.language,
                  title: 'Language',
                  subtitle: 'English',
                  onTap: () => _showInformation(
                    'Language',
                    'ResQRoad is currently available in English.',
                  ),
                ),
                _SettingsMenuTile(
                  icon: Icons.lock_outline,
                  title: 'Privacy & data',
                  onTap: () => _showInformation(
                    'Privacy & data',
                    'Incident reports and safety settings are stored in your private account. Incident photos are stored only on this device and are not uploaded.',
                  ),
                ),
                _SettingsMenuTile(
                  icon: Icons.help_outline,
                  title: 'Help & support',
                  onTap: () => _showInformation(
                    'Help & support',
                    'This is a prototype. It does not contact emergency services or dispatch responders. For immediate danger, contact your local emergency services directly.',
                  ),
                ),
                _SettingsMenuTile(
                  icon: Icons.info_outline,
                  title: 'About ResQRoad',
                  subtitle: 'Version 1.0',
                  onTap: () => _showInformation(
                    'About ResQRoad',
                    'ResQRoad is a road-safety prototype. Emergency alerts and driving monitoring are simulated.',
                  ),
                ),
              ],
            ),
            if (_locationError != null) ...[
              const SizedBox(height: 8),
              Text(
                _locationError!,
                style: const TextStyle(color: AppColors.red, fontSize: 11),
              ),
            ],
            if (_saving) ...[
              const SizedBox(height: 8),
              const Text(
                'Saving settings…',
                style: TextStyle(color: AppColors.muted, fontSize: 10),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.red, fontSize: 11),
              ),
            ],
            const SizedBox(height: 22),
            if (widget.onSignOut != null)
              OutlinedButton.icon(
                onPressed: _saving ? null : widget.onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            if (widget.onSignOut != null) const SizedBox(height: 12),
            const Text(
              'ResQRoad prototype · Reports and safety settings sync to your account. Photos stay on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 9),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addContact(ProfileSettings settings) async {
    final contact = await showDialog<EmergencyContact>(
      context: context,
      builder: (context) => const _AddEmergencyContactDialog(),
    );
    if (contact != null && mounted) {
      await _update(
        settings.copyWith(contacts: [...settings.contacts, contact]),
      );
    }
  }
}

class _AddEmergencyContactDialog extends StatefulWidget {
  const _AddEmergencyContactDialog();

  @override
  State<_AddEmergencyContactDialog> createState() =>
      _AddEmergencyContactDialogState();
}

class _AddEmergencyContactDialogState
    extends State<_AddEmergencyContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _relationship = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _relationship.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      EmergencyContact(
        name: _name.text.trim(),
        relationship: _relationship.text.trim(),
        phone: _phone.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Add emergency contact'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ContactInput(controller: _name, label: 'Full name'),
            _ContactInput(controller: _relationship, label: 'Relationship'),
            _ContactInput(
              controller: _phone,
              label: 'Phone number',
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _ContactInput extends StatelessWidget {
  const _ContactInput({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Required' : null,
      ),
    );
  }
}

class _CardColumn extends StatelessWidget {
  const _CardColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Setting extends StatelessWidget {
  const _Setting({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 10)),
      value: value,
      activeTrackColor: AppColors.orange,
      onChanged: onChanged,
    );
  }
}

String _locationStatusLabel(LocationAccessStatus? status) {
  return switch (status) {
    LocationAccessStatus.granted => 'Allowed while using the app',
    LocationAccessStatus.denied => 'Permission not granted',
    LocationAccessStatus.permanentlyDenied => 'Blocked in device settings',
    LocationAccessStatus.servicesDisabled => 'Device location is turned off',
    null => 'Checking device access…',
  };
}

class _SettingsMenuTile extends StatelessWidget {
  const _SettingsMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        child: Icon(icon, size: 19),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 10)),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

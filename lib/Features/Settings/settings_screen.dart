import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../../Core/settings_provider.dart';
import '../../Core/backup_service.dart';
import '../Auth/auth_provider.dart' as ledgix_auth;
import '../Auth/edit_profile_screen.dart';
import '../../shared/widgets/app_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBackingUp = false;
  final LocalAuthentication auth_local = LocalAuthentication();

  final List<String> currencies = const [
    'AED', 'USD', 'EUR', 'GBP', 'INR', 'PKR', 'SAR', 'OMR', 'KWD', 'BHD', 'QAR',
  ];

  Future<void> _toggleBiometrics(bool value, SettingsProvider settings) async {
    if (value) {
      try {
        final bool canAuthenticateWithBiometrics = await auth_local.canCheckBiometrics;
        final bool canAuthenticate = canAuthenticateWithBiometrics || await auth_local.isDeviceSupported();
        
        if (!canAuthenticate) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Biometric authentication is not available on this device.')),
            );
          }
          return;
        }

        final bool didAuthenticate = await auth_local.authenticate(
          localizedReason: 'Please authenticate to enable biometric login',
          options: const AuthenticationOptions(stickyAuth: true),
        );

        if (didAuthenticate) {
          settings.setBiometricEnabled(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    } else {
      settings.setBiometricEnabled(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final auth = Provider.of<ledgix_auth.LedGixAuthProvider>(context);
    final user = auth.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // User Profile Section
              const Text('Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 30,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      child: Icon(Icons.person, size: 30, color: theme.colorScheme.primary),
                    ),
                    title: Text(user?.name ?? 'Guest User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.email ?? 'login to sync data', style: const TextStyle(fontSize: 12)),
                        if (user?.ledgixId != null)
                          Text('ID: ${user!.ledgixId}', style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    isThreeLine: user?.ledgixId != null,
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () {
                        if (user != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text('Security & Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.fingerprint, color: Colors.teal),
                      title: const Text('Biometric Lock'),
                      subtitle: const Text('Require biometrics to open app'),
                      value: settings.biometricEnabled,
                      onChanged: (val) => _toggleBiometrics(val, settings),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.brightness_4_outlined, color: Colors.indigo),
                      title: const Text('Theme Mode'),
                      trailing: DropdownButton<ThemeMode>(
                        value: settings.themeMode,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                          DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                        ],
                        onChanged: (ThemeMode? newValue) {
                          if (newValue != null) {
                            settings.setThemeMode(newValue);
                          }
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.currency_exchange, color: Colors.blue),
                      title: const Text('Default Currency'),
                      subtitle: settings.isFetchingRates ? const Text('Fetching live rates...', style: TextStyle(fontSize: 10)) : Text('Rates updated from live feed', style: TextStyle(fontSize: 10, color: Colors.green.shade700)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (settings.isFetchingRates)
                            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          DropdownButton<String>(
                            value: currencies.contains(settings.currency) ? settings.currency : currencies.first,
                            underline: const SizedBox(),
                            items: currencies.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                settings.setCurrency(newValue);
                                if (user != null) {
                                  auth.updateProfile(user.copyWith(preferredCurrency: newValue));
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('Backup & Restore', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.cloud_download_outlined, color: theme.colorScheme.primary),
                      title: const Text('Download Full Backup'),
                      subtitle: const Text('Export all data as JSON file'),
                      onTap: _handleExportBackup,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.cloud_upload_outlined, color: Colors.orange),
                      title: const Text('Upload / Restore Backup'),
                      subtitle: const Text('Select and restore from JSON file'),
                      onTap: _handleImportBackup,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('App Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Image.asset('assets/logo/ledgix_logo.png', height: 24, errorBuilder: (c,e,s) => const Icon(Icons.info_outline)),
                      title: const Text('Version'),
                      trailing: const Text('2.0.2'),
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Know where your money goes.'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Logout',
                icon: Icons.logout,
                color: Colors.red,
                isOutlined: true,
                onPressed: () => auth.logout(),
              ),
              const SizedBox(height: 40),
            ],
          ),
          if (_isBackingUp)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Future<void> _handleExportBackup() async {
    setState(() => _isBackingUp = true);
    try {
      await BackupService.exportFullBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _handleImportBackup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Data'),
        content: const Text('This will add/restore data to your LedGix app. It may merge with existing data. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isBackingUp = true);
    final error = await BackupService.importBackup();
    if (mounted) {
      setState(() => _isBackingUp = false);
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }
}

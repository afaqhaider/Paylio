import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings_provider.dart';
import 'biometric_service.dart';

class SecurityWrapper extends StatefulWidget {
  final Widget child;
  const SecurityWrapper({super.key, required this.child});

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper> with WidgetsBindingObserver {
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometrics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      setState(() {
        _isAuthenticated = false;
      });
    } else if (state == AppLifecycleState.resumed || state == AppLifecycleState.inactive) {
      // Inactive is often used on iOS when the app switcher is opened
      _checkBiometrics();
    }
  }

  Future<void> _checkBiometrics() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.biometricEnabled) {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
        });
      }
      return;
    }

    if (_isAuthenticated || _isAuthenticating) return;

    if (mounted) {
      setState(() {
        _isAuthenticating = true;
      });
    }

    final success = await BiometricService.authenticate();

    if (mounted) {
      setState(() {
        _isAuthenticated = success;
        _isAuthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) {
      return widget.child;
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Color(0xFF0F766E)),
            const SizedBox(height: 24),
            const Text(
              'Paylio is Locked',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please authenticate to continue',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _checkBiometrics,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock with Biometrics'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

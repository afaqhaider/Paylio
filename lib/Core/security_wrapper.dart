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
    // Use a post-frame callback to ensure context is fully available if needed,
    // though for checking biometrics we can start immediately or wait for provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometrics();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("AppLifecycleState changed to: $state");
    if (state == AppLifecycleState.paused) {
      setState(() {
        _isAuthenticated = false;
      });
    } else if (state == AppLifecycleState.resumed) {
      _checkBiometrics();
    }
  }

  Future<void> _checkBiometrics() async {
    if (!mounted) return;
    
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    
    // Wait for settings to be loaded if they aren't yet
    if (!settings.isLoaded) {
      debugPrint("SecurityWrapper: Settings not loaded, waiting...");
      // We can't easily "wait" here without a loop or a listener, 
      // but usually settings load very fast.
      // Let's rely on didUpdateWidget or just re-check if settings changed.
      return;
    }

    if (!settings.biometricEnabled) {
      debugPrint("SecurityWrapper: Biometrics disabled in settings.");
      setState(() {
        _isAuthenticated = true;
      });
      return;
    }

    if (_isAuthenticated || _isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    debugPrint("SecurityWrapper: Triggering Biometric Authentication");
    final success = await BiometricService.authenticate();
    debugPrint("SecurityWrapper: Authentication result: $success");

    if (mounted) {
      setState(() {
        _isAuthenticated = success;
        _isAuthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-check if settings just loaded and we aren't authenticated yet
    final settings = Provider.of<SettingsProvider>(context);
    if (settings.isLoaded && !_isAuthenticated && !_isAuthenticating) {
      // Trigger check in next frame to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkBiometrics());
    }

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
            if (settings.isLoaded)
              ElevatedButton.icon(
                onPressed: _checkBiometrics,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock with Biometrics'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                ),
              )
            else
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

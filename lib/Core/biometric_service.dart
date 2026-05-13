import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> canAuthenticate() async {
    final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
    return canAuthenticate;
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to access Paylio',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Biometric login required',
            deviceCredentialsRequiredTitle: 'Biometric login required',
          ),
          IOSAuthMessages(
            cancelButton: 'No thanks',
          ),
        ],
      );
    } on PlatformException catch (e) {
      print(e);
      return false;
    }
  }
}

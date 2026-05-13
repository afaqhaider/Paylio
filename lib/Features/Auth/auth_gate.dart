import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Core/security_wrapper.dart';
import '../Dashboard/Home_Screen.dart';
import 'login_screen.dart';
import '../../shared/loading_screen.dart';
import '../../shared/error_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Log auth state changes for debugging
        if (snapshot.connectionState != ConnectionState.waiting) {
          debugPrint("Auth state changed: ${snapshot.hasData ? 'User logged in (${snapshot.data?.email})' : 'User logged out'}");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint("AuthGate waiting for initialization...");
          return const LoadingScreen();
        }
        
        if (snapshot.hasError) {
          debugPrint("AuthGate critical error: ${snapshot.error}");
          return ErrorScreen(message: "Authentication Error: ${snapshot.error}");
        }

        if (snapshot.hasData) {
          debugPrint("AuthGate: Redirecting to HomeScreen");
          return const SecurityWrapper(child: HomeScreen());
        }

        debugPrint("AuthGate: Redirecting to LoginScreen");
        return const LoginScreen();
      },
    );
  }
}

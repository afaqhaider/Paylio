import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint("AuthGate waiting");
          return const LoadingScreen();
        }
        
        if (snapshot.hasError) {
          debugPrint("AuthGate error: ${snapshot.error}");
          return ErrorScreen(message: snapshot.error.toString());
        }

        if (snapshot.hasData) {
          debugPrint("Showing HomeScreen");
          return const HomeScreen();
        }

        debugPrint("Showing LoginScreen");
        return const LoginScreen();
      },
    );
  }
}

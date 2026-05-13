import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Features/Dashboard/Home_Screen.dart';
import 'Core/settings_provider.dart';
import 'Features/Auth/auth_gate.dart';
import 'Features/Auth/auth_provider.dart' as paylio_auth;
import 'Features/Auth/login_screen.dart';
import 'shared/loading_screen.dart';
import 'shared/error_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase and await it to prevent [core/no-app] error
  await Firebase.initializeApp();
  debugPrint("Firebase initialized");

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => paylio_auth.PaylioAuthProvider()),
      ],
      child: const PaylioApp(),
    ),
  );
}

class PaylioApp extends StatelessWidget {
  const PaylioApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Modern Fintech Color Palette
    const primaryTeal = Color(0xFF0F766E);
    const darkNavy = Color(0xFF111827);
    const softWhite = Color(0xFFF9FAFB);
    const cardWhite = Color(0xFFFFFFFF);

    return MaterialApp(
      title: 'Paylio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: softWhite,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryTeal,
          primary: primaryTeal,
          secondary: darkNavy,
          surface: cardWhite,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: softWhite,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: darkNavy,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(color: darkNavy),
        ),
        cardTheme: CardThemeData(
          color: cardWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryTeal,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryTeal, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(color: darkNavy.withOpacity(0.6)),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: darkNavy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: cardWhite,
          selectedItemColor: primaryTeal,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: darkNavy,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
          ),
          titleLarge: TextStyle(
            color: darkNavy,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(
            color: darkNavy,
            fontSize: 16,
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

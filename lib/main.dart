import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'Core/settings_provider.dart';
import 'Features/Auth/auth_gate.dart';
import 'Features/Auth/auth_provider.dart' as paylio_auth;
import 'Features/Accounts/account_provider.dart';
import 'Features/Transactions/transaction_provider.dart';
import 'Features/Budgets/budget_provider.dart';
import 'Features/Categories/category_provider.dart';
import 'Features/People/person_provider.dart';
import 'Features/Commitments/commitment_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Error Handling
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint("Flutter Error: ${details.exception}");
    debugPrintStack(stackTrace: details.stack);
  };

  try {
    // Initialize Firebase and await it to prevent [core/no-app] error
    await Firebase.initializeApp();
    debugPrint("Firebase initialized successfully");
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
    // If Firebase fails, we still want to see the error in the app if possible
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => paylio_auth.PaylioAuthProvider()),
        ChangeNotifierProvider(create: (_) => AccountProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => PersonProvider()),
        ChangeNotifierProvider(create: (_) => CommitmentProvider()),
      ],
      child: const PaylioApp(),
    ),
  );
}

class PaylioApp extends StatelessWidget {
  const PaylioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<paylio_auth.PaylioAuthProvider>(context);
    final themePreference = auth.user?.themePreference ?? 'system';

    ThemeMode themeMode;
    if (themePreference == 'light') {
      themeMode = ThemeMode.light;
    } else if (themePreference == 'dark') {
      themeMode = ThemeMode.dark;
    } else {
      themeMode = ThemeMode.system;
    }

    // Modern Fintech Color Palette
    const primaryTeal = Color(0xFF0F766E);
    const darkNavy = Color(0xFF111827);
    const softWhite = Color(0xFFF9FAFB);
    const cardWhite = Color(0xFFFFFFFF);

    return MaterialApp(
      title: 'Paylio',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
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
            side: BorderSide(color: Colors.grey.withAlpha(25)),
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
            borderSide: BorderSide(color: Colors.grey.withAlpha(51)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withAlpha(25)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryTeal, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(color: darkNavy.withAlpha(153)),
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
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryTeal,
          brightness: Brightness.dark,
          primary: primaryTeal,
          secondary: const Color(0xFF111827),
          surface: const Color(0xFF111827),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF111827),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withAlpha(25)),
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
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF111827),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withAlpha(51)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withAlpha(25)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryTeal, width: 2),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.black,
          selectedItemColor: primaryTeal,
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'Core/settings_provider.dart';
import 'Core/theme_data.dart';
import 'Core/notification_service.dart';
import 'Features/Auth/auth_gate.dart';
import 'Features/Auth/auth_provider.dart' as ledgix_auth;
import 'Features/Accounts/account_provider.dart';
import 'Features/Transactions/transaction_provider.dart';
import 'Features/Budgets/budget_provider.dart';
import 'Features/Categories/category_provider.dart';
import 'Features/People/person_provider.dart';
import 'Features/Commitments/commitment_provider.dart';
import 'Features/Transactions/shared_transaction_provider.dart';
import 'Features/Goals/goal_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Error Handling
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint("Flutter Error: ${details.exception}");
    debugPrintStack(stackTrace: details.stack);
  };

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    debugPrint("Firebase initialized successfully");
    await NotificationService.initialize();
    debugPrint("Notification service initialized");
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ledgix_auth.LedGixAuthProvider()),
        ChangeNotifierProvider(create: (_) => AccountProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProxyProvider<ledgix_auth.LedGixAuthProvider, PersonProvider>(
          create: (context) => PersonProvider(),
          update: (context, auth, person) {
            person?.updateUserId(auth.user?.ledgixId);
            return person ?? PersonProvider();
          },
        ),
        ChangeNotifierProxyProvider<ledgix_auth.LedGixAuthProvider, SharedTransactionProvider>(
          create: (context) => SharedTransactionProvider(),
          update: (context, auth, shared) {
            shared?.updateUserId(auth.user?.ledgixId);
            return shared ?? SharedTransactionProvider();
          },
        ),
        ChangeNotifierProvider(create: (_) => CommitmentProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
      ],
      child: const LedGixApp(),
    ),
  );
}

class LedGixApp extends StatelessWidget {
  const LedGixApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    
    return MaterialApp(
      title: 'LedGix',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.getLightTheme(),
      darkTheme: AppThemes.getDarkTheme(),
      themeMode: settings.themeMode,
      home: const AuthGate(),
    );
  }
}

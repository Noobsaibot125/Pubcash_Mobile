import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/colors.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/complete_social_profile_screen.dart';
import 'screens/main_navigation_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On garde le edgeToEdge pour un rendu moderne
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      // 👇 CORRECTION : On met BLANC ici pour prolonger ta barre de menu
      systemNavigationBarColor: Colors.white,

      // Pas de ligne de séparation
      systemNavigationBarDividerColor: Colors.transparent,

      // Icônes foncées (gris sombre) pour être visibles sur le blanc
      systemNavigationBarIconBrightness: Brightness.dark,

      // Barre du haut transparente
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,

      // Désactive le "scrim" (voile sombre) que Android met parfois par défaut
      systemNavigationBarContrastEnforced: false,
    ),
  );

  try {
    await Firebase.initializeApp();
    print("✅ Firebase connectée !");
  } catch (e) {
    print("❌ Erreur Firebase: $e");
  }

  await NotificationService().initialiser();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthService()..init())],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'PubCash Mobile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const MainNavigationScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (authService.isAuthenticated) {
      if (authService.currentUser == null && authService.isLoading) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      if (authService.requiresProfileCompletion) {
        return const CompleteSocialProfileScreen();
      }

      return const MainNavigationScreen();
    }

    return const LoginScreen();
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // <--- 1. IMPORT OBLIGATOIRE
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/colors.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/complete_social_profile_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() async {
  // S'assurer que les liaisons Flutter sont prêtes
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. INITIALISER FIREBASE EN PREMIER (Indispensable pour éviter l'écran blanc)
  try {
    await Firebase.initializeApp();
    print("✅ Firebase connectée !");
  } catch (e) {
    print("❌ Erreur Firebase: $e");
  }

  // Initialiser le service de notifications (Firebase + Local)
  // Maintenant que Firebase est prêt, on peut lancer ce service sans crash
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
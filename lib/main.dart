import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'utils/colors.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/complete_social_profile_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() {
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

    // Si l'utilisateur est authentifié (token présent)
    if (authService.isAuthenticated) {
      // Si on charge encore les infos utilisateur (init en cours)
      if (authService.currentUser == null && authService.isLoading) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      // Si le profil nécessite d'être complété (Social Login incomplet)
      if (authService.requiresProfileCompletion) {
        return const CompleteSocialProfileScreen();
      }

      // Sinon -> Navigation Principale
      return const MainNavigationScreen();
    }

    // Sinon -> Login
    return const LoginScreen();
  }
}

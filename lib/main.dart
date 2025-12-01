import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 1. IMPORT OBLIGATOIRE POUR LE SYSTEMCHROME
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

  // 👇 2. AJOUT : C'EST ICI QU'ON ENLÈVE L'EFFET DE "MARGE" EN BAS
  // On active le mode "Edge to Edge" pour que l'app prenne tout l'écran
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // On configure la couleur de la barre pour qu'elle soit transparente ou blanche
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    // En mettant transparent, le fond de ton app sera visible derrière les boutons
    systemNavigationBarColor: Colors.transparent, 
    // On met les icônes (rond, carré, triangle) en noir pour qu'on les voie sur fond clair
    systemNavigationBarIconBrightness: Brightness.dark, 
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  // 👆 FIN DE L'AJOUT

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
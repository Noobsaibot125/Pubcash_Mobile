import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'forgot_password_screen.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart'; // <--- N'OUBLIE PAS L'IMPORT ICI
import '../../utils/colors.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/social_login_buttons.dart';
import 'register_screen.dart';
import 'complete_social_profile_screen.dart';
import '../../utils/exceptions.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
bool _obscurePassword = true;
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      try {
        // 1. Connexion
        await Provider.of<AuthService>(context, listen: false)
            .login(_emailController.text.trim(), _passwordController.text);
        
        // ✅ 2. SAUVEGARDE TOKEN FCM (CRUCIAL)
        // Maintenant qu'on a un token d'auth, on envoie le token FCM
        try {
          await NotificationService().forceRefreshToken();
          print("✅ Token FCM mis à jour après login");
        } catch (e) {
          print("⚠️ Erreur mise à jour FCM: $e");
        }

        // 3. Navigation
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
        
      } on IncompleteProfileException {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CompleteSocialProfileScreen(),
            ),
          );
        }
      } catch (e) {
        final msg = AuthService.getErrorMessage(e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return LoadingOverlay(
      isLoading: authService.isLoading,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Center(
                      child: Image.asset('assets/images/logo.png', height: 100),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Connexion',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.primary,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Bienvenue sur PubCash',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 40),

                   CustomTextField(
  hintText: "Email ou Numéro",
  prefixIcon: Icons.person_outline, // Icône plus générique que l'email
  controller: _emailController, // Tu peux garder ce nom ou le renommer _identifierController
  keyboardType: TextInputType.emailAddress, // Ce clavier affiche le @ et les chiffres, c'est parfait pour les deux
  validator: (value) {
    if (value == null || value.isEmpty) {
      return "Veuillez entrer votre email ou numéro";
    }

    // 1. Vérification Email (Regex standard)
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    // 2. Vérification Numéro (Uniquement des chiffres, min 10 caractères)
    final phoneRegex = RegExp(r'^[0-9]{10,}$'); 

    // Si ce n'est NI un email NI un numéro valide
    if (!emailRegex.hasMatch(value) && !phoneRegex.hasMatch(value)) {
      return "Entrez un email valide ou un numéro (ex: 0707...)";
    }
    
    return null;
  },
),
                  const SizedBox(height: 20), // Un peu d'espace

                    // 2. REMPLACE LE CHAMP MOT DE PASSE PAR CELUI-CI
                    CustomTextField(
                      hintText: "Mot de passe",
                      prefixIcon: Icons.lock_outline,
                      controller: _passwordController,
                      obscureText: _obscurePassword, // Utilise la variable
                      validator: Validators.validatePassword,
                      // Ajout de l'icône "Oeil" à droite
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword 
                              ? Icons.visibility_outlined 
                              : Icons.visibility_off_outlined,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())
                          );
                        },
                        child: const Text(
                          "Mot de passe oublié ?",
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    CustomButton(text: "SE CONNECTER", onPressed: _handleLogin),

                    const SizedBox(height: 30),

                    const Text(
                      "Ou connectez-vous avec",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),

                    const SizedBox(height: 20),

                    SocialLoginButtons(
                      onFacebookTap: () async {
                        try {
                          await authService.loginWithFacebook();
                          
                          // ✅ Mettre à jour le token FCM après login FB
                          await NotificationService().forceRefreshToken();

                          if (mounted) {
                            Navigator.of(context).pushReplacementNamed('/home');
                          }
                        } on IncompleteProfileException {
                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CompleteSocialProfileScreen(),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur connexion: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    onGoogleTap: () async {
                        print("🔵 Clic sur Google Login");
                        try {
                          await authService.loginWithGoogle();
                          print("🟢 Login Google terminé");

                          // ✅ Mettre à jour le token FCM après login Google
                          await NotificationService().forceRefreshToken();

                          if (mounted) {
                            Navigator.of(context).pushReplacementNamed('/home');
                          }
                        } on IncompleteProfileException {
                          print("🟠 Profil incomplet -> Redirection");
                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CompleteSocialProfileScreen(),
                              ),
                            );
                          }
                        } catch (e) {
                          // ✅ CORRECTION ICI : Gestion de l'annulation
                          if (e.toString().contains('GOOGLE_CANCELED')) {
                            print("L'utilisateur a annulé la connexion Google (Pas d'erreur affichée)");
                            return; // ON ARRÊTE TOUT, ON NE FAIT RIEN
                          }

                          print("🔴 Erreur Google Login: $e");
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                    ),

                    const SizedBox(height: 40),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Pas encore de compte ? ",
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "S'inscrire",
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
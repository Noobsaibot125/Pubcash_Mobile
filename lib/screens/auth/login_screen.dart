import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'forgot_password_screen.dart';
import '../../services/auth_service.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

 Future<void> _handleLogin() async {
  if (_formKey.currentState!.validate()) {
    try {
      await Provider.of<AuthService>(context, listen: false)
          .login(_emailController.text.trim(), _passwordController.text);
      
      // ✅ CORRECTION ICI : On force la navigation vers l'accueil
      if (mounted) {
        // On utilise pushReplacementNamed pour qu'on ne puisse pas revenir au login avec "retour"
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
                      hintText: "Email",
                      prefixIcon: Icons.email_outlined,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.validateEmail,
                    ),

                    CustomTextField(
                      hintText: "Mot de passe",
                      prefixIcon: Icons.lock_outline,
                      obscureText: true,
                      controller: _passwordController,
                      validator: Validators.validatePassword,
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
      // ✅ CORRECTION ICI AUSSI
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
    }catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Erreur connexion: ${e.toString()}',
                                ),
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
      print("🟢 Login Google Service terminé");
      
      // ✅ CORRECTION ICI AUSSI
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
      
    } on IncompleteProfileException{
    print("🟠 Profil incomplet -> Redirection"); // Log 3
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CompleteSocialProfileScreen()),
      );
    }
  } catch (e) {
    print("🔴 Erreur Google Login: $e"); // Log 4
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

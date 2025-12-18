import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // <--- IMPORTANT : Ajouter cet import
import 'forgot_password_screen.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
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

  // --- NOUVELLE FONCTION : POPUP COMPTE BLOQUÉ ---
  void _showBlockedPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // L'utilisateur doit cliquer sur OK ou le lien
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.red),
              SizedBox(width: 10),
              Text("Compte Bloqué"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Votre compte a été suspendu par l'administrateur. Pour plus d'informations, veuillez ",
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 5),
                // --- LE LIEN CLIQUABLE ---
                GestureDetector(
                  onTap: () async {
                    // Préparation de l'email
                    final Uri emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: 'redfieldluise@gmail.com',
                      query:
                          'subject=Réclamation Compte Bloqué&body=Bonjour, mon compte est bloqué. Voici mon identifiant : ${_emailController.text}',
                    );

                    try {
                      await launchUrl(emailLaunchUri);
                    } catch (e) {
                      print("Impossible d'ouvrir l'app mail : $e");
                      // Fallback si l'app mail ne s'ouvre pas
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Impossible d'ouvrir l'application mail.",
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    "contacter le support",
                    style: TextStyle(
                      color: Colors.blue, // Couleur du lien
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline, // Souligné
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                const Text("par email.", style: TextStyle(fontSize: 16)),
                const SizedBox(height: 15),
                // Affichage de l'email en clair au cas où
                SelectableText(
                  "Email: redfieldluise@gmail.com",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // Fermer le popup
              },
              child: const Text("Fermer"),
            ),
          ],
        );
      },
    );
  }

  // --- NOUVELLE FONCTION : POPUP D'ERREUR STYLÉ ---
  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 50,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "D'accord",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      try {
        await Provider.of<AuthService>(
          context,
          listen: false,
        ).login(_emailController.text.trim(), _passwordController.text);

        try {
          await NotificationService().forceRefreshToken();
        } catch (e) {
          print("⚠️ Erreur mise à jour FCM: $e");
        }

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
        // --- CORRECTION ICI ---

        // 1. On récupère le message lisible (celui qui s'affiche dans le rouge sur ton écran)
        final String readableMessage = AuthService.getErrorMessage(e);

        // 2. On garde l'erreur brute au cas où le code technique s'y trouve
        final String rawError = e.toString();

        // 3. On vérifie LES DEUX (Le code technique OU le mot clé dans le message lisible)
        if (rawError.contains("ACCOUNT_BLOCKED") ||
            readableMessage.toLowerCase().contains("bloqué") ||
            readableMessage.toLowerCase().contains("suspendu")) {
          // C'est un blocage -> On affiche le popup
          if (mounted) _showBlockedPopup(context);
        } else if (readableMessage.toLowerCase().contains("connexion") ||
            readableMessage.toLowerCase().contains("internet") ||
            readableMessage.toLowerCase().contains("réseau")) {
          // C'est une erreur réseau -> Dialogue stylé
          if (mounted)
            _showErrorDialog(context, "Erreur de connexion", readableMessage);
        } else {
          // C'est une autre erreur (mot de passe faux, etc.) -> On affiche le SnackBar rouge
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(readableMessage),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  // ... (Le reste de votre build reste identique, copiez le code ci-dessous si besoin)
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
                      prefixIcon: Icons.person_outline,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Veuillez entrer votre email ou numéro";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    CustomTextField(
                      hintText: "Mot de passe",
                      prefixIcon: Icons.lock_outline,
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      validator: Validators.validatePassword,
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
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
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
                          await NotificationService().forceRefreshToken();
                          if (mounted)
                            Navigator.of(context).pushReplacementNamed('/home');
                        } catch (e) {
                          // --- CORRECTION APPLIQUÉE ICI ---
                          final String readableMessage =
                              AuthService.getErrorMessage(e);
                          final String rawError = e.toString();

                          if (rawError.contains("ACCOUNT_BLOCKED") ||
                              readableMessage.toLowerCase().contains(
                                "bloqué",
                              ) ||
                              readableMessage.toLowerCase().contains(
                                "suspendu",
                              )) {
                            if (mounted) _showBlockedPopup(context);
                          } else if (readableMessage.toLowerCase().contains(
                                "connexion",
                              ) ||
                              readableMessage.toLowerCase().contains(
                                "internet",
                              ) ||
                              readableMessage.toLowerCase().contains(
                                "réseau",
                              )) {
                            if (mounted)
                              _showErrorDialog(
                                context,
                                "Erreur de connexion",
                                readableMessage,
                              );
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(readableMessage),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      onGoogleTap: () async {
                        try {
                          await authService.loginWithGoogle();
                          await NotificationService().forceRefreshToken();
                          if (mounted)
                            Navigator.of(context).pushReplacementNamed('/home');
                        } catch (e) {
                          if (e.toString().contains('GOOGLE_CANCELED')) return;

                          // --- CORRECTION APPLIQUÉE ICI ---
                          final String readableMessage =
                              AuthService.getErrorMessage(e);
                          final String rawError = e.toString();

                          if (rawError.contains("ACCOUNT_BLOCKED") ||
                              readableMessage.toLowerCase().contains(
                                "bloqué",
                              ) ||
                              readableMessage.toLowerCase().contains(
                                "suspendu",
                              )) {
                            if (mounted) _showBlockedPopup(context);
                          } else if (readableMessage.toLowerCase().contains(
                                "connexion",
                              ) ||
                              readableMessage.toLowerCase().contains(
                                "internet",
                              ) ||
                              readableMessage.toLowerCase().contains(
                                "réseau",
                              )) {
                            if (mounted)
                              _showErrorDialog(
                                context,
                                "Erreur de connexion",
                                readableMessage,
                              );
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(readableMessage),
                                backgroundColor: Colors.red,
                              ),
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

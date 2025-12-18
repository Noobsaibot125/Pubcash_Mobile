import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // <--- 1. IMPORT AJOUTÉ
import '../../utils/exceptions.dart';
import 'complete_social_profile_screen.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../models/ville.dart';
import '../../utils/api_constants.dart';
import '../../utils/colors.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/social_login_buttons.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  // Controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dateController = TextEditingController();
  final _contactController = TextEditingController();
  final _referralController = TextEditingController();

  // State pour les Dropdowns
  String? _selectedVilleNom;
  String? _selectedCommune;
  String _selectedGenre = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  List<Ville> _villes = [];
  List<String> _communes = [];
  bool _isLoadingCommunes = false;

  @override
  void initState() {
    super.initState();
    _loadVilles();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dateController.dispose();
    _contactController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  // --- 2. FONCTION POPUP COMPTE BLOQUÉ (IDENTIQUE AU LOGIN) ---
  void _showBlockedPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
                GestureDetector(
                  onTap: () async {
                    // On essaie de récupérer l'email du champ s'il est rempli, sinon texte générique
                    final emailBody = _emailController.text.isNotEmpty
                        ? "Bonjour, mon compte lié à ${_emailController.text} est bloqué."
                        : "Bonjour, mon compte est bloqué.";

                    final Uri emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: 'redfieldluise@gmail.com',
                      query:
                          'subject=Réclamation Compte Bloqué&body=$emailBody',
                    );

                    try {
                      await launchUrl(emailLaunchUri);
                    } catch (e) {
                      print("Impossible d'ouvrir l'app mail : $e");
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
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                const Text("par email.", style: TextStyle(fontSize: 16)),
                const SizedBox(height: 15),
                SelectableText(
                  "Email: redfieldluise@gmail.com",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Fermer"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadVilles() async {
    try {
      final response = await _apiService.get(ApiConstants.villes);
      final List<dynamic> data = response.data;
      setState(() {
        _villes = data.map((json) => Ville.fromJson(json)).toList();
      });
    } catch (e) {
      print("Erreur chargement villes: $e");
    }
  }

  Future<void> _loadCommunes(String villeNom) async {
    setState(() {
      _isLoadingCommunes = true;
      _communes = [];
      _selectedCommune = null;
    });
    try {
      final response = await _apiService.get(
        ApiConstants.communes,
        queryParameters: {'ville': villeNom},
      );
      final List<dynamic> data = response.data;
      setState(() {
        _communes = data.map((json) => json['nom'].toString()).toList();
      });
    } catch (e) {
      print("Erreur chargement communes: $e");
    } finally {
      setState(() => _isLoadingCommunes = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
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

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedVilleNom == null) {
        _showError("Veuillez sélectionner une ville");
        return;
      }
      if (_selectedCommune == null) {
        _showError("Veuillez sélectionner une commune");
        return;
      }
      if (_selectedGenre.isEmpty) {
        _showError("Veuillez sélectionner votre genre");
        return;
      }

      try {
        final authService = Provider.of<AuthService>(context, listen: false);

        final success = await authService.register(
          nomUtilisateur: _usernameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          ville: _selectedVilleNom!,
          commune: _selectedCommune!,
          dateNaissance: _dateController.text,
          contact: _contactController.text,
          genre: _selectedGenre,
          codeParrainage: _referralController.text,
        );

        if (success && mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: const Center(
                child: Text(
                  "Inscription Réussie !",
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 60,
                  ),
                  SizedBox(height: 15),
                  Text(
                    "Votre compte a été créé avec succès.\nVous pouvez maintenant vous connecter.",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Aller à la connexion",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        final String readableMessage = AuthService.getErrorMessage(e);
        final String rawError = e.toString();

        if (rawError.contains("ACCOUNT_BLOCKED") ||
            readableMessage.toLowerCase().contains("bloqué") ||
            readableMessage.toLowerCase().contains("suspendu")) {
          if (mounted) _showBlockedPopup(context);
        } else if (readableMessage.toLowerCase().contains("connexion") ||
            readableMessage.toLowerCase().contains("internet") ||
            readableMessage.toLowerCase().contains("réseau")) {
          if (mounted)
            _showErrorDialog(context, "Erreur de connexion", readableMessage);
        } else {
          _showError(readableMessage);
        }
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return LoadingOverlay(
      isLoading: authService.isLoading,
      child: Scaffold(
        backgroundColor: AppColors.light,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: BackButton(color: AppColors.primary),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Créer un compte',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Rejoignez la communauté PubCash',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 30),

                    CustomTextField(
                      hintText: "Nom d'utilisateur",
                      prefixIcon: Icons.person_outline,
                      controller: _usernameController,
                      validator: (v) =>
                          Validators.validateRequired(v, "Nom d'utilisateur"),
                    ),
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

                    CustomTextField(
                      hintText: "Confirmer mot de passe",
                      prefixIcon: Icons.lock_outline,
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      validator: (v) => Validators.validateConfirmPassword(
                        v,
                        _passwordController.text,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),

                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: CustomTextField(
                          controller: _dateController,
                          hintText: 'Date de naissance',
                          prefixIcon: Icons.calendar_today,
                          validator: (v) =>
                              Validators.validateRequired(v, 'Date'),
                        ),
                      ),
                    ),

                    CustomTextField(
                      hintText: "Téléphone",
                      prefixIcon: Icons.phone_android,
                      controller: _contactController,
                      keyboardType: TextInputType.phone,
                      validator: Validators.validatePhone,
                    ),

                    _buildDropdownContainer(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedVilleNom,
                          hint: const Text("Choisir une ville"),
                          isExpanded: true,
                          icon: const Icon(
                            Icons.location_city,
                            color: AppColors.primary,
                          ),
                          items: _villes
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v.nom,
                                  child: Text(v.nom),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedVilleNom = val;
                              _selectedCommune = null;
                            });
                            if (val != null) _loadCommunes(val);
                          },
                        ),
                      ),
                    ),

                    _buildDropdownContainer(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCommune,
                          hint: Text(
                            _isLoadingCommunes
                                ? "Chargement..."
                                : "Choisir une commune",
                          ),
                          isExpanded: true,
                          icon: const Icon(Icons.map, color: AppColors.primary),
                          items: _communes
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: _selectedVilleNom == null
                              ? null
                              : (val) => setState(() => _selectedCommune = val),
                        ),
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.only(left: 5, bottom: 5),
                      child: Text(
                        "Genre",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Homme'),
                            value: 'Homme',
                            groupValue: _selectedGenre,
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) =>
                                setState(() => _selectedGenre = val!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Femme'),
                            value: 'Femme',
                            groupValue: _selectedGenre,
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) =>
                                setState(() => _selectedGenre = val!),
                          ),
                        ),
                      ],
                    ),

                    CustomTextField(
                      hintText: "Code Parrainage (Optionnel)",
                      prefixIcon: Icons.card_giftcard,
                      controller: _referralController,
                    ),

                    const SizedBox(height: 20),

                    CustomButton(
                      text: "S'INSCRIRE",
                      onPressed: _handleRegister,
                    ),

                    const SizedBox(height: 20),
                    const Text(
                      "Ou inscrivez-vous avec",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 15),

                    // --- 3. MODIFICATION DES BOUTONS SOCIAUX ---
                    SocialLoginButtons(
                      onFacebookTap: () async {
                        try {
                          await authService.loginWithFacebook();
                          await NotificationService().forceRefreshToken();

                          if (mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/home',
                              (route) => false,
                            );
                          }
                        } on IncompleteProfileException {
                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CompleteSocialProfileScreen(),
                              ),
                            );
                          }
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

                          if (mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/home',
                              (route) => false,
                            );
                          }
                        } on IncompleteProfileException {
                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CompleteSocialProfileScreen(),
                              ),
                            );
                          }
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

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Déjà inscrit ? ",
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            "Se connecter",
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

  Widget _buildDropdownContainer({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Pour formater la date
import '../../utils/exceptions.dart'; // <--- INDISPENSABLE pour IncompleteProfileException
import 'complete_social_profile_screen.dart'; // <--- INDISPENSABLE pour la navigation
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
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
  // On utilise ApiService directement ici juste pour charger les villes/communes
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

  // Charger la liste des villes
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

  // Charger les communes selon la ville choisie
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

  // Sélecteur de date
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

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      // Validations manuelles supplémentaires
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
          // Affichage Modale Succès
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Center(child: Text("Inscription Réussie !", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green, size: 60),
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
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {
                      Navigator.pop(ctx); // Ferme dialog
                      Navigator.pop(context); // Retour login
                    },
                    child: const Text("Aller à la connexion", style: TextStyle(color: Colors.white)),
                  ),
                )
              ],
            ),
          );
        }
      } catch (e) {
        _showError(e.toString().replaceAll('Exception:', ''));
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
                    // --- HEADER ---
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

                    // --- CHAMPS TEXTE ---
                    CustomTextField(
                      hintText: "Nom d'utilisateur",
                      prefixIcon: Icons.person_outline,
                      controller: _usernameController,
                      validator: (v) => Validators.validateRequired(v, "Nom d'utilisateur"),
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
                      obscureText: _obscurePassword, // Variable 1
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

                    // 3. REMPLACE LE CHAMP CONFIRMER MOT DE PASSE
                    CustomTextField(
                      hintText: "Confirmer mot de passe",
                      prefixIcon: Icons.lock_outline,
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword, // Variable 2
                      validator: (v) => Validators.validateConfirmPassword(v, _passwordController.text),
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

                    // --- DATE NAISSANCE ---
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: CustomTextField(
                          controller: _dateController,
                          hintText: 'Date de naissance',
                          prefixIcon: Icons.calendar_today,
                          validator: (v) => Validators.validateRequired(v, 'Date'),
                        ),
                      ),
                    ),

                    // --- CONTACT ---
                    CustomTextField(
                      hintText: "Téléphone",
                      prefixIcon: Icons.phone_android,
                      controller: _contactController,
                      keyboardType: TextInputType.phone,
                      validator: Validators.validatePhone,
                    ),

                    // --- DROPDOWN VILLE ---
                    _buildDropdownContainer(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedVilleNom,
                          hint: const Text("Choisir une ville"),
                          isExpanded: true,
                          icon: const Icon(Icons.location_city, color: AppColors.primary),
                          items: _villes.map((v) => DropdownMenuItem(value: v.nom, child: Text(v.nom))).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedVilleNom = val;
                              _selectedCommune = null; // Reset commune
                            });
                            if (val != null) _loadCommunes(val);
                          },
                        ),
                      ),
                    ),

                    // --- DROPDOWN COMMUNE ---
                    _buildDropdownContainer(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCommune,
                          hint: Text(_isLoadingCommunes ? "Chargement..." : "Choisir une commune"),
                          isExpanded: true,
                          icon: const Icon(Icons.map, color: AppColors.primary),
                          items: _communes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: _selectedVilleNom == null ? null : (val) => setState(() => _selectedCommune = val),
                        ),
                      ),
                    ),

                    // --- GENRE ---
                    const Padding(
                      padding: EdgeInsets.only(left: 5, bottom: 5),
                      child: Text("Genre", style: TextStyle(fontWeight: FontWeight.bold)),
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
                            onChanged: (val) => setState(() => _selectedGenre = val!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Femme'),
                            value: 'Femme',
                            groupValue: _selectedGenre,
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) => setState(() => _selectedGenre = val!),
                          ),
                        ),
                      ],
                    ),

                    // --- PARRAINAGE ---
                    CustomTextField(
                      hintText: "Code Parrainage (Optionnel)",
                      prefixIcon: Icons.card_giftcard,
                      controller: _referralController,
                    ),

                    const SizedBox(height: 20),

                    // --- BOUTON INSCRIPTION ---
                    CustomButton(
                      text: "S'INSCRIRE",
                      onPressed: _handleRegister,
                    ),

                    const SizedBox(height: 20),
                    const Text("Ou inscrivez-vous avec", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 15),

                    // --- BOUTONS SOCIAUX ---
                     SocialLoginButtons(
                      onFacebookTap: () async {
                        try {
                          await authService.loginWithFacebook();
                          
                          // 1. Succès -> On va à l'accueil et on efface l'historique
                          if (mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/home', 
                              (route) => false
                            );
                          }
                        } on IncompleteProfileException {
                          // 2. Exception Profil -> On va à la page de complétion
                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CompleteSocialProfileScreen(),
                              ),
                            );
                          }
                        } catch (e) {
                          // 3. Autre erreur -> On l'affiche
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Erreur Facebook: $e"), 
                                backgroundColor: Colors.red
                              ),
                            );
                          }
                        }
                      },
                      onGoogleTap: () async {
                        try {
                          await authService.loginWithGoogle();
                          
                          // 1. Succès -> On va à l'accueil et on efface l'historique
                          if (mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/home', 
                              (route) => false
                            );
                          }
                        } on IncompleteProfileException {
                          // 2. Exception Profil -> On va à la page de complétion
                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CompleteSocialProfileScreen(),
                              ),
                            );
                          }
                        } catch (e) {
                          // 3. Autre erreur -> On l'affiche
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Erreur Google: $e"), 
                                backgroundColor: Colors.red
                              ),
                            );
                          }
                        }
                      },
                    ),

                    const SizedBox(height: 20),
                    
                    // --- LIEN CONNEXION ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Déjà inscrit ? ", style: TextStyle(color: AppColors.textMuted)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text("Se connecter", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
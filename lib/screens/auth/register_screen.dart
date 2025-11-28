import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../models/ville.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../utils/colors.dart';
import '../../utils/validators.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/social_login_buttons.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _contactController = TextEditingController();
  final _dateController = TextEditingController();
  final _referralController = TextEditingController();

  // State variables
  String? _selectedGenre;
  String? _selectedVille;
  String? _selectedCommune;
  List<Ville> _villes = [];
  List<String> _communes = [];
  bool _isLoadingVilles = false;
  bool _isLoadingCommunes = false;

  @override
  void initState() {
    super.initState();
    _fetchVilles();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _contactController.dispose();
    _dateController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _fetchVilles() async {
    setState(() => _isLoadingVilles = true);
    try {
      final apiService = ApiService();
      final response = await apiService.get(AppConstants.villesEndpoint);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        setState(() {
          _villes = data.map((json) => Ville.fromJson(json)).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur chargement villes: $e')));
    } finally {
      setState(() => _isLoadingVilles = false);
    }
  }

  Future<void> _fetchCommunes(String villeNom) async {
    setState(() {
      _isLoadingCommunes = true;
      _selectedCommune = null;
      _communes = [];
    });
    try {
      final apiService = ApiService();
      final response = await apiService.get(
        AppConstants.communesEndpoint,
        queryParameters: {'ville': villeNom},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        setState(() {
          _communes = data.map((json) => json['nom'].toString()).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur chargement communes: $e')));
    } finally {
      setState(() => _isLoadingCommunes = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
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
      if (_selectedCommune == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez sélectionner une commune')),
        );
        return;
      }

      final user = User(
        nomUtilisateur: _usernameController.text,
        email: _emailController.text,
        commune: _selectedCommune,
        ville: _selectedVille,
        dateNaissance: _dateController.text,
        contact: _contactController.text,
        genre: _selectedGenre,
      );

      // Ajouter code parrainage si présent (à gérer dans AuthService ou User model)
      // Pour l'instant on passe l'objet User standard

      try {
        final success = await Provider.of<AuthService>(
          context,
          listen: false,
        ).register(user, _passwordController.text);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inscription réussie ! Connectez-vous.'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context); // Retour au login
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur inscription: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // Logo
                  Center(
                    child: Image.asset('assets/images/logo.png', height: 80),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Inscription',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.primary,
                      fontSize: 28,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),

                  // Champs
                  CustomTextField(
                    hintText: "Nom d'utilisateur *",
                    prefixIcon: Icons.person_outline,
                    controller: _usernameController,
                    validator: (v) =>
                        Validators.validateRequired(v, "Nom d'utilisateur"),
                  ),
                  CustomTextField(
                    hintText: "Email *",
                    prefixIcon: Icons.email_outlined,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.validateEmail,
                  ),
                  CustomTextField(
                    hintText: "Mot de passe *",
                    prefixIcon: Icons.lock_outline,
                    obscureText: true,
                    controller: _passwordController,
                    validator: Validators.validatePassword,
                  ),
                  CustomTextField(
                    hintText: "Confirmer mot de passe *",
                    prefixIcon: Icons.lock_outline,
                    obscureText: true,
                    controller: _confirmPasswordController,
                    validator: (v) => Validators.validateConfirmPassword(
                      v,
                      _passwordController.text,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Date Naissance
                  CustomTextField(
                    hintText: "Date de naissance",
                    prefixIcon: Icons.calendar_today,
                    controller: _dateController,
                    readOnly: true,
                    onTap: () => _selectDate(context),
                  ),

                  // Contact
                  CustomTextField(
                    hintText: "Contact",
                    prefixIcon: Icons.phone_android,
                    controller: _contactController,
                    keyboardType: TextInputType.phone,
                  ),

                  // Genre Dropdown
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGenre,
                        hint: const Text("Genre"),
                        isExpanded: true,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.primary,
                        ),
                        items: ['Homme', 'Femme'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedGenre = newValue;
                          });
                        },
                      ),
                    ),
                  ),

                  // Ville Dropdown
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.2),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isLoadingVilles
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedVille,
                              hint: const Text("Choisir une ville"),
                              isExpanded: true,
                              icon: const Icon(
                                Icons.location_city,
                                color: AppColors.primary,
                              ),
                              items: _villes.map((Ville ville) {
                                return DropdownMenuItem<String>(
                                  value: ville.nom,
                                  child: Text(ville.nom),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedVille = newValue;
                                  _fetchCommunes(newValue!);
                                });
                              },
                            ),
                          ),
                  ),

                  // Commune Dropdown
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isLoadingCommunes
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCommune,
                              hint: const Text("Choisir une commune *"),
                              isExpanded: true,
                              icon: const Icon(
                                Icons.map,
                                color: AppColors.primary,
                              ),
                              items: _communes.map((String nom) {
                                return DropdownMenuItem<String>(
                                  value: nom,
                                  child: Text(nom),
                                );
                              }).toList(),
                              onChanged: _selectedVille == null
                                  ? null
                                  : (newValue) {
                                      setState(() {
                                        _selectedCommune = newValue;
                                      });
                                    },
                            ),
                          ),
                  ),

                  // Code Parrainage
                  CustomTextField(
                    hintText: "Code Parrainage (Optionnel)",
                    prefixIcon: Icons.card_giftcard,
                    controller: _referralController,
                  ),

                  const SizedBox(height: 30),

                  CustomButton(
                    text: "CRÉER MON COMPTE",
                    onPressed: _handleRegister,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Ou inscrivez-vous avec",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),

                  const SizedBox(height: 15),

                  SocialLoginButtons(
                    onFacebookTap: () => authService.loginWithFacebook(),
                    onGoogleTap: () => authService.loginWithGoogle(),
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
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

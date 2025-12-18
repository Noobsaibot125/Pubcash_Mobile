import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart'; // ✅ Import présent
import '../../models/ville.dart';
import '../../utils/api_constants.dart';
import '../../utils/colors.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_overlay.dart';

class CompleteSocialProfileScreen extends StatefulWidget {
  const CompleteSocialProfileScreen({super.key});

  @override
  State<CompleteSocialProfileScreen> createState() =>
      _CompleteSocialProfileScreenState();
}

class _CompleteSocialProfileScreenState
    extends State<CompleteSocialProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  // Controllers
  final _dateController = TextEditingController();
  final _contactController = TextEditingController();

  // State
  String? _selectedVilleId;
  String? _selectedCommune;
  String _selectedGenre = 'M';
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
    _dateController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _loadVilles() async {
    try {
      final response = await _apiService.get(ApiConstants.villes);
      final List<dynamic> data = response.data;
      setState(() {
        _villes = data.map((json) => Ville.fromJson(json)).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur chargement villes: $e')));
      }
    }
  }

  Future<void> _loadCommunes(String villeId) async {
    setState(() {
      _isLoadingCommunes = true;
      _communes = [];
      _selectedCommune = null;
    });
    try {
      final ville = _villes.firstWhere((v) => v.id.toString() == villeId);

      final response = await _apiService.get(
        ApiConstants.communes,
        queryParameters: {'ville': ville.nom},
      );

      final List<dynamic> data = response.data;
      setState(() {
        _communes = data.map((json) => json['nom'].toString()).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement communes: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingCommunes = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
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
  void _showErrorDialog(
    BuildContext context,
    String title,
    String message, {
    IconData icon = Icons.error_outline_rounded,
  }) {
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
                child: Icon(icon, size: 50, color: Colors.redAccent),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                textAlign: TextAlign.center,
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

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedVilleId == null || _selectedCommune == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez sélectionner une ville et une commune'),
          ),
        );
        return;
      }

      final authService = Provider.of<AuthService>(context, listen: false);

      try {
        // DETERMINATION DU FLUX : Inscription Sociale Atomique (Nouveau) vs Update Profil (Existant)
        if (authService.pendingSocialData != null) {
          print("🚀 Flux : Inscription Sociale Atomique...");
          await authService.registerSocial(
            commune: _selectedCommune!,
            dateNaissance: _dateController.text,
            contact: _contactController.text,
            genre: _selectedGenre,
          );
        } else {
          print("📝 Flux : Mise à jour de profil classique...");
          // 1. Enregistrement du profil
          await authService.completeProfile(
            commune: _selectedCommune!,
            dateNaissance: _dateController.text,
            contact: _contactController.text,
            genre: _selectedGenre,
          );
        }

        // ============================================================
        // ✅ CORRECTION AJOUTÉE ICI : ENVOI DU TOKEN FCM
        // ============================================================
        try {
          print("💾 Profil complété, tentative de sauvegarde du token FCM...");
          await NotificationService().forceRefreshToken();
          print("✅ Token FCM sauvegardé avec succès.");
        } catch (e) {
          print("⚠️ Erreur silencieuse lors de l'envoi du token FCM: $e");
          // On ne bloque pas la navigation si ça échoue, mais on logue l'erreur
        }
        // ============================================================

        // 2. Navigation vers l'accueil
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      } catch (e) {
        final String readableMessage = AuthService.getErrorMessage(e);
        if (mounted) {
          if (readableMessage.toLowerCase().contains("déjà utilisé") ||
              readableMessage.toLowerCase().contains("existe déjà")) {
            _showErrorDialog(
              context,
              "Données déjà utilisées",
              readableMessage,
              icon: Icons.person_off_rounded,
            );
          } else if (readableMessage.toLowerCase().contains("connexion") ||
              readableMessage.toLowerCase().contains("internet") ||
              readableMessage.toLowerCase().contains("réseau")) {
            _showErrorDialog(
              context,
              "Erreur de connexion",
              readableMessage,
              icon: Icons.wifi_off_rounded,
            );
          } else {
            _showErrorDialog(
              context,
              "Une erreur est survenue",
              readableMessage,
            );
          }
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
                    const SizedBox(height: 20),
                    Text(
                      'Complétez votre profil',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Quelques informations supplémentaires pour mieux vous connaître.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    // Ville Dropdown
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedVilleId,
                          hint: const Text('Sélectionnez votre ville'),
                          isExpanded: true,
                          icon: const Icon(
                            Icons.location_city,
                            color: AppColors.primary,
                          ),
                          items: _villes.map((Ville ville) {
                            return DropdownMenuItem<String>(
                              value: ville.id.toString(),
                              child: Text(ville.nom),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedVilleId = newValue;
                            });
                            if (newValue != null) {
                              _loadCommunes(newValue);
                            }
                          },
                        ),
                      ),
                    ),

                    // Commune Dropdown
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCommune,
                          hint: _isLoadingCommunes
                              ? const Text('Chargement...')
                              : const Text('Sélectionnez votre commune'),
                          isExpanded: true,
                          icon: const Icon(Icons.map, color: AppColors.primary),
                          items: _communes.map((String nom) {
                            return DropdownMenuItem<String>(
                              value: nom,
                              child: Text(nom),
                            );
                          }).toList(),
                          onChanged: _selectedVilleId == null
                              ? null
                              : (String? newValue) {
                                  setState(() {
                                    _selectedCommune = newValue;
                                  });
                                },
                        ),
                      ),
                    ),

                    // Date de Naissance
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: CustomTextField(
                          controller: _dateController,
                          hintText: 'Date de naissance (YYYY-MM-DD)',
                          prefixIcon: Icons.calendar_today,
                          validator: (v) => Validators.validateRequired(
                            v,
                            'Date de naissance',
                          ),
                        ),
                      ),
                    ),

                    // Contact
                    CustomTextField(
                      controller: _contactController,
                      hintText: 'Votre numéro de téléphone',
                      prefixIcon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: Validators.validatePhone,
                    ),

                    const SizedBox(height: 20),

                    // Genre
                    const Text(
                      'Genre',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Homme'),
                            value: 'M',
                            groupValue: _selectedGenre,
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (value) {
                              setState(() {
                                _selectedGenre = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Femme'),
                            value: 'F',
                            groupValue: _selectedGenre,
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (value) {
                              setState(() {
                                _selectedGenre = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    CustomButton(
                      text: 'ENREGISTRER ET CONTINUER',
                      onPressed: _submit,
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

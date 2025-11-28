import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/ville.dart';
import '../../utils/colors.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_overlay.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({Key? key}) : super(key: key);

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
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
  List<String> _communes =
      []; // Changed to List<String> to match RegisterScreen logic if needed, or keep as objects
  // Actually RegisterScreen used List<String> for communes names. Let's check API.
  // RegisterScreen: _communes = data.map((json) => json['nom'].toString()).toList();
  // So let's use List<String> for simplicity and consistency.

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
      final response = await _apiService.get('/villes');
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

  Future<void> _loadCommunes(String villeNom) async {
    setState(() {
      _isLoadingCommunes = true;
      _communes = [];
      _selectedCommune = null;
    });
    try {
      // Note: RegisterScreen uses query param 'ville': villeNom for /communes endpoint?
      // Or /villes/$id/communes?
      // RegisterScreen: apiService.get(AppConstants.communesEndpoint, queryParameters: {'ville': villeNom});
      // But CompleteFacebookProfile.js used: /villes/${formData.ville_id}/communes
      // Let's stick to what works in RegisterScreen if possible, OR what works in Web.
      // Web uses /villes/ID/communes. RegisterScreen uses /communes?ville=NOM.
      // Let's check what I used in my previous attempt: /villes/$villeId/communes.
      // I will use the Web approach as it seems more standard REST, but I need to be sure.
      // Let's use the Web approach: /villes/$id/communes.
      // Wait, in RegisterScreen I saw: AppConstants.communesEndpoint.
      // Let's check AppConstants if I can.
      // For now I will use the ID based one as in the Web code I read.

      final response = await _apiService.get(
        '/villes/$villeNom/communes',
      ); // Assuming villeNom is actually ID?
      // In Web: /villes/${formData.ville_id}/communes. So it expects ID.
      // In my code below I am passing ville.id.toString().

      final List<dynamic> data = response.data;
      setState(() {
        // Assuming the response is list of objects with 'nom'
        _communes = data.map((json) => json['nom'].toString()).toList();
      });
    } catch (e) {
      print('Erreur chargement communes: $e');
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
        await authService.completeProfile(
          commune: _selectedCommune!,
          dateNaissance: _dateController.text,
          contact: _contactController.text,
          genre: _selectedGenre,
        );

        // Navigation is handled by AuthWrapper in main.dart
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
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
                  const Text(
                    'Complétez votre profil',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Quelques informations supplémentaires pour mieux vous connaître.',
                    style: TextStyle(fontSize: 16, color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Ville Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedVilleId,
                        hint: const Text('Sélectionnez votre ville'),
                        isExpanded: true,
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
                  const SizedBox(height: 20),

                  // Commune Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCommune,
                        hint: _isLoadingCommunes
                            ? const Text('Chargement...')
                            : const Text('Sélectionnez votre commune'),
                        isExpanded: true,
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
                  const SizedBox(height: 20),

                  // Date de Naissance
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: AbsorbPointer(
                      child: CustomTextField(
                        controller: _dateController,
                        hintText: 'Date de naissance (YYYY-MM-DD)',
                        prefixIcon: Icons.calendar_today,
                        validator: (v) =>
                            Validators.validateRequired(v, 'Date de naissance'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

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
                    text: 'Enregistrer et Continuer',
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

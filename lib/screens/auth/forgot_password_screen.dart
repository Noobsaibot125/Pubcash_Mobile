import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_overlay.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 1; // 1: Email, 2: Code, 3: New Password
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final auth = Provider.of<AuthService>(context, listen: false);
    
    try {
      if (_step == 1) {
        await auth.forgotPassword(_emailController.text.trim());
        _showMessage("Code envoyé à ${_emailController.text}");
        setState(() => _step = 2);
      } else if (_step == 2) {
        await auth.verifyResetCode(_emailController.text.trim(), _codeController.text.trim());
        _showMessage("Code vérifié !");
        setState(() => _step = 3);
      } else if (_step == 3) {
        if (_passController.text != _confirmPassController.text) {
          _showMessage("Les mots de passe ne correspondent pas", isError: true);
          return;
        }
        await auth.resetPassword(
          _emailController.text.trim(),
          _codeController.text.trim(),
          _passController.text,
        );
        if (mounted) {
          _showMessage("Mot de passe modifié avec succès !");
          Navigator.pop(context); // Retour au login
        }
      }
    } catch (e) {
      _showMessage(AuthService.getErrorMessage(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = Provider.of<AuthService>(context).isLoading;

    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Mot de passe oublié"),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.black),
          titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Indicateur d'étape
                Row(
                  children: [
                    _buildStepDot(1),
                    _buildStepLine(),
                    _buildStepDot(2),
                    _buildStepLine(),
                    _buildStepDot(3),
                  ],
                ),
                const SizedBox(height: 40),
                
                if (_step == 1) ...[
                  const Text("Entrez votre email pour recevoir un code de réinitialisation.", textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _emailController,
                    hintText: "Email",
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.contains('@') ? null : "Email invalide",
                  ),
                ],

                if (_step == 2) ...[
                  Text("Un code a été envoyé à ${_emailController.text}", textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _codeController,
                    hintText: "Code (ex: 123 456)",
                    prefixIcon: Icons.lock_clock_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.length < 3 ? "Code trop court" : null,
                  ),
                  TextButton(
                    onPressed: () => setState(() => _step = 1),
                    child: const Text("Changer d'email", style: TextStyle(color: AppColors.primary)),
                  )
                ],

                if (_step == 3) ...[
                  const Text("Créez votre nouveau mot de passe", textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _passController,
                    hintText: "Nouveau mot de passe",
                    prefixIcon: Icons.lock_outline,
                    obscureText: true,
                    validator: (v) => v!.length < 6 ? "Minimum 6 caractères" : null,
                  ),
                  CustomTextField(
                    controller: _confirmPassController,
                    hintText: "Confirmer le mot de passe",
                    prefixIcon: Icons.lock_outline,
                    obscureText: true,
                  ),
                ],

                const Spacer(),
                CustomButton(
                  text: _step == 3 ? "TERMINER" : "CONTINUER",
                  onPressed: _handleSubmit,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepDot(int step) {
    bool isActive = _step >= step;
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text("$step", style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStepLine() {
    return Expanded(child: Container(height: 2, color: Colors.grey[300]));
  }
}
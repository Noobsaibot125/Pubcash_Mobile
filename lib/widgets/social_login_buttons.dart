import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SocialLoginButtons extends StatelessWidget {
  final VoidCallback onFacebookTap;
  final VoidCallback onGoogleTap;

  const SocialLoginButtons({
    super.key,
    required this.onFacebookTap,
    required this.onGoogleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSocialButton(
          icon:
              'assets/icons/facebook.svg', // Assurez-vous d'avoir cette icône ou utilisez Icon
          color: const Color(0xFF3b5998),
          onTap: onFacebookTap,
          isIcon: false,
          iconData: Icons.facebook,
        ),
        const SizedBox(width: 20),
        _buildSocialButton(
          icon: 'assets/icons/google.svg',
          color: Colors.white,
          onTap: onGoogleTap,
          isIcon:
              true, // Google logo is usually complex, better as SVG or Image, here using Icon for simplicity if SVG missing
          iconData: null, // Placeholder if no SVG
          isGoogle: true,
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required String icon,
    required Color color,
    required VoidCallback onTap,
    bool isIcon = false,
    IconData? iconData,
    bool isGoogle = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: isGoogle
              ? const Text(
                  'G',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ) // Placeholder simple pour Google
              : Icon(iconData, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';

class SocialLoginButtons extends StatelessWidget {
  final VoidCallback? onAppleTap;
  final VoidCallback onGoogleTap;

  const SocialLoginButtons({
    super.key,
    this.onAppleTap,
    required this.onGoogleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Bouton Apple - uniquement sur iOS
        if (Platform.isIOS && onAppleTap != null) ...[
          _buildSocialButton(
            color: Colors.black,
            onTap: onAppleTap!,
            isApple: true,
          ),
          const SizedBox(width: 20),
        ],
        // Bouton Google - toujours visible
        _buildSocialButton(
          color: Colors.white,
          onTap: onGoogleTap,
          isGoogle: true,
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required Color color,
    required VoidCallback onTap,
    bool isApple = false,
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
          child: isApple
              ? const Icon(Icons.apple, color: Colors.white, size: 35)
              : isGoogle
              ? const Text(
                  'G',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

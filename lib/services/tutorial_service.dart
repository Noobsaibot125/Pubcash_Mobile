import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../widgets/app_tutorial_dialog.dart';

class TutorialService {
  static const String _keyTutorialSeen = 'tutorial_seen_v1';

  static Future<void> showTutorialIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeen = prefs.getBool(_keyTutorialSeen) ?? false;

    if (!hasSeen) {
      if (!context.mounted) return;

      // On affiche le dialogue
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AppTutorialDialog(),
      );

      // On marque comme vu
      await prefs.setBool(_keyTutorialSeen, true);
    }
  }

  // Pour forcer l'affichage (depuis le profil par exemple, bien que le profil appelle directement le widget)
  static Future<void> markAsUnseen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTutorialSeen, false);
  }
}

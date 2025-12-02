import 'package:flutter/material.dart';
import '../utils/colors.dart';
import 'home_screen.dart';
import 'gains_screen.dart';
import 'games/game_hub_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  
  // 👇 AJOUT : Variable pour stocker le nombre de vidéos
  int _videoBadgeCount = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  
  // 👇 AJOUT : Méthode appelée par HomeScreen quand les données chargent
  void _updateVideoCount(int count) {
      // On ne fait le setState que si le nombre a changé pour éviter des rebuilds inutiles
      if (_videoBadgeCount != count) {
        // On utilise addPostFrameCallback pour éviter les erreurs de setState pendant le build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _videoBadgeCount = count;
            });
          }
        });
      }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        goToProfile: () => _onItemTapped(3), 
        // 👇 CONNEXION : On passe la fonction de mise à jour
        onVideoCountChanged: _updateVideoCount,
      ),
      const GainsScreen(),
      const GameHubScreen(),
      const ProfileScreen(),
    ];
    
    // Couleurs
    final whatsappDarkGreen = const Color(0xFFFF6B35); 
    final whatsappLightGreen = whatsappDarkGreen.withOpacity(0.2); 

    return Scaffold(
      body: screens[_selectedIndex],
      
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: whatsappLightGreen,
          labelTextStyle: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black);
            }
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.black);
          }),
        ),
        child: NavigationBar(
          height: 70,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped, 
          animationDuration: const Duration(seconds: 1),
          destinations: [
            // === ONGLETS ===
            NavigationDestination(
              icon: Badge(
                // 👇 DYNAMIQUE : On affiche le nombre réel
                label: Text('$_videoBadgeCount'),
                // 👇 PROPRE : On cache le badge si 0 vidéo
                isLabelVisible: _videoBadgeCount > 0, 
                backgroundColor: whatsappDarkGreen,
                textColor: Colors.white,
                child: const Icon(Icons.home_outlined),
              ),
              selectedIcon: Badge(
                label: Text('$_videoBadgeCount'),
                isLabelVisible: _videoBadgeCount > 0,
                backgroundColor: whatsappDarkGreen,
                child: const Icon(Icons.home, color: Colors.black),
              ),
              label: 'Accueil',
            ),
            
            NavigationDestination(
              icon: Badge(
                smallSize: 8,
                backgroundColor: whatsappDarkGreen,
                child: const Icon(Icons.account_balance_wallet_outlined),
              ),
              selectedIcon: const Icon(Icons.account_balance_wallet, color: Colors.black),
              label: 'Gain',
            ),
            
            NavigationDestination(
              icon: const Icon(Icons.games_outlined),
              selectedIcon: const Icon(Icons.games, color: Colors.black),
              label: 'Jeu',
            ),
            
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person, color: Colors.black),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
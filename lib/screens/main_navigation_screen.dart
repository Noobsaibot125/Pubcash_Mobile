import 'dart:async'; // Nécessaire pour le Timer
import 'package:flutter/material.dart';
import 'package:pubcash_mobile/services/message_service.dart'; // Assure-toi que le chemin est bon

import 'home_screen.dart';
import 'gains_screen.dart';
import 'games/game_hub_screen.dart';
import 'messaging/inbox_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  
  // Badge pour les notifications générales (Vidéos/Système)
  int _videoBadgeCount = 0; 
  
  // Badge pour les messages privés
  int _messageBadgeCount = 0; 

  final MessageService _messageService = MessageService();
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _fetchMessageCount();
    
    // Optionnel : Polling toutes les 30 secondes pour mettre à jour le badge message
    // ou tu peux appeler _fetchMessageCount() à chaque fois que l'écran s'affiche
    _messageTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchMessageCount();
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  // Fonction pour récupérer le nombre de messages non lus
  Future<void> _fetchMessageCount() async {
    try {
      int count = await _messageService.getUnreadCount();
      if (mounted && count != _messageBadgeCount) {
        setState(() {
          _messageBadgeCount = count;
        });
      }
    } catch (e) {
      print("Erreur badge message: $e");
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    // Si on clique sur l'onglet Messages, on rafraichit le compteur (il devrait passer à 0 après lecture dans l'écran)
    if (index == 3) {
      // Petit délai pour laisser le temps à l'utilisateur de lire ou à l'API de marquer lu
      Future.delayed(const Duration(seconds: 2), _fetchMessageCount);
    }
  }

  void _updateVideoCount(int count) {
    if (_videoBadgeCount != count) {
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
        goToProfile: () => _onItemTapped(4),
        onVideoCountChanged: _updateVideoCount,
      ),
      const GainsScreen(),
      const GameHubScreen(),
      const InboxScreen(),
      const ProfileScreen(),
    ];

    final whatsappDarkGreen = const Color(0xFFFF6B35);
    final whatsappLightGreen = whatsappDarkGreen.withOpacity(0.2);

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: whatsappLightGreen,
          labelTextStyle: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              );
            }
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: Colors.black,
            );
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
            // Onglet Accueil
            NavigationDestination(
              icon: Badge(
                label: Text('$_videoBadgeCount'),
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

            // Onglet Gain
            NavigationDestination(
              icon: Badge(
                smallSize: 8,
                backgroundColor: whatsappDarkGreen,
                isLabelVisible: false, // Pas de compteur ici pour l'instant
                child: const Icon(Icons.account_balance_wallet_outlined),
              ),
              selectedIcon: const Icon(
                Icons.account_balance_wallet,
                color: Colors.black,
              ),
              label: 'Gain',
            ),

            // Onglet Jeu
            NavigationDestination(
              icon: const Icon(Icons.games_outlined),
              selectedIcon: const Icon(Icons.games, color: Colors.black),
              label: 'Jeu',
            ),

            // Onglet Messages (MODIFIÉ)
            NavigationDestination(
              icon: Badge(
                label: Text('$_messageBadgeCount'),
                isLabelVisible: _messageBadgeCount > 0,
                backgroundColor: Colors.red, // Rouge pour les messages urgents/chat
                textColor: Colors.white,
                child: const Icon(Icons.chat_bubble_outline),
              ),
              selectedIcon: Badge(
                label: Text('$_messageBadgeCount'),
                isLabelVisible: _messageBadgeCount > 0,
                backgroundColor: Colors.red,
                child: const Icon(Icons.chat_bubble, color: Colors.black),
              ),
              label: 'Messages',
            ),

            // Onglet Profil
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
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pubcash_mobile/services/message_service.dart';

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
    
    // Polling toutes les 30 secondes pour mettre à jour le badge message
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
    
    // Si on clique sur l'onglet Messages, on rafraichit le compteur
    if (index == 3) {
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

    // TA COULEUR ORANGE
    final primaryOrange = const Color(0xFFFF6B35); 
    // Couleur de fond de la pilule (orange très clair)
    final indicatorColor = primaryOrange.withOpacity(0.2); 

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: screens),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: indicatorColor, // Fond orange clair
            labelTextStyle: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primaryOrange, // TEXTE EN ORANGE ICI
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
              // --- Onglet Accueil ---
              NavigationDestination(
                icon: Badge(
                  label: Text('$_videoBadgeCount'),
                  isLabelVisible: _videoBadgeCount > 0,
                  backgroundColor: primaryOrange,
                  textColor: Colors.white,
                  child: const Icon(Icons.home_outlined),
                ),
                selectedIcon: Badge(
                  label: Text('$_videoBadgeCount'),
                  isLabelVisible: _videoBadgeCount > 0,
                  backgroundColor: primaryOrange,
                  // MODIFICATION : Icone en orange
                  child: Icon(Icons.home, color: primaryOrange), 
                ),
                label: 'Accueil',
              ),

              // --- Onglet Gain ---
              NavigationDestination(
                icon: Badge(
                  smallSize: 8,
                  backgroundColor: primaryOrange,
                  isLabelVisible: false,
                  child: const Icon(Icons.account_balance_wallet_outlined),
                ),
                // MODIFICATION : Icone en orange
                selectedIcon: Icon(
                  Icons.account_balance_wallet,
                  color: primaryOrange, 
                ),
                label: 'Gain',
              ),

              // --- Onglet Jeu ---
              NavigationDestination(
                icon: const Icon(Icons.games_outlined),
                // MODIFICATION : Icone en orange
                selectedIcon: Icon(Icons.games, color: primaryOrange),
                label: 'Jeu',
              ),

              // --- Onglet Messages ---
              NavigationDestination(
                icon: Badge(
                  label: Text('$_messageBadgeCount'),
                  isLabelVisible: _messageBadgeCount > 0,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  child: const Icon(Icons.chat_bubble_outline),
                ),
                selectedIcon: Badge(
                  label: Text('$_messageBadgeCount'),
                  isLabelVisible: _messageBadgeCount > 0,
                  backgroundColor: Colors.red,
                  // MODIFICATION : Icone en orange
                  child: Icon(Icons.chat_bubble, color: primaryOrange),
                ),
                label: 'Messages',
              ),

              // --- Onglet Profil ---
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                // MODIFICATION : Icone en orange
                selectedIcon: Icon(Icons.person, color: primaryOrange),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
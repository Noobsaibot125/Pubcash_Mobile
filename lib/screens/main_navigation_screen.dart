import 'package:flutter/material.dart';

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
  int _videoBadgeCount = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
    // Liste des écrans
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

            NavigationDestination(
              icon: Badge(
                smallSize: 8,
                backgroundColor: whatsappDarkGreen,
                child: const Icon(Icons.account_balance_wallet_outlined),
              ),
              selectedIcon: const Icon(
                Icons.account_balance_wallet,
                color: Colors.black,
              ),
              label: 'Gain',
            ),

            NavigationDestination(
              icon: const Icon(Icons.games_outlined),
              selectedIcon: const Icon(Icons.games, color: Colors.black),
              label: 'Jeu',
            ),

            NavigationDestination(
              icon: const Icon(Icons.chat_bubble_outline),
              selectedIcon: const Icon(Icons.chat_bubble, color: Colors.black),
              label: 'Messages',
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

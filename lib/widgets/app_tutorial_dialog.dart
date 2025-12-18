import 'package:flutter/material.dart';
import '../utils/colors.dart';
import 'package:dio/dio.dart';
import '../utils/api_constants.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AppTutorialDialog extends StatefulWidget {
  const AppTutorialDialog({super.key});

  @override
  State<AppTutorialDialog> createState() => _AppTutorialDialogState();
}

class _AppTutorialDialogState extends State<AppTutorialDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _loading = true;

  List<Map<String, String>> _pages = [
    {
      'title': 'Bienvenue sur PubCash',
      'description':
          'La première application qui vous rémunère pour votre attention.',
      'image': '',
    },
    {
      'title': 'Regardez & Gagnez',
      'description':
          'Regardez des vidéos publicitaires, aimez et partagez pour cumuler des points FCFA.',
      'image': '',
    },
    {
      'title': 'Retrait Instantané',
      'description':
          'Échangez vos gains contre du crédit ou de l\'argent via MTN, Orange, Moov ou Wave.',
      'image': '',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchTutorialImages();
  }

  Future<void> _fetchTutorialImages() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        '${ApiConstants.baseUrl}/admin/info-accueil',
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final rootUrl =
            ApiConstants.socketUrl; // Utilise l'URL racine (sans /api)
        print("DEBUG TUTORIAL: Données reçues: $data");

        setState(() {
          if (data['tutorial_image_1'] != null &&
              data['tutorial_image_1'].toString().isNotEmpty) {
            final path = data['tutorial_image_1'];
            _pages[0]['image'] = path.startsWith('http')
                ? path
                : '$rootUrl$path';
          }
          if (data['tutorial_image_2'] != null &&
              data['tutorial_image_2'].toString().isNotEmpty) {
            final path = data['tutorial_image_2'];
            _pages[1]['image'] = path.startsWith('http')
                ? path
                : '$rootUrl$path';
          }
          if (data['tutorial_image_3'] != null &&
              data['tutorial_image_3'].toString().isNotEmpty) {
            final path = data['tutorial_image_3'];
            _pages[2]['image'] = path.startsWith('http')
                ? path
                : '$rootUrl$path';
          }
          print(
            "DEBUG TUTORIAL: URLs finales: ${_pages.map((p) => p['image']).toList()}",
          );
          _loading = false;
        });
      }
    } catch (e) {
      print("Erreur chargement images tutoriel: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : _pages[index]['image']!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: _pages[index]['image']!,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: AppColors.primary.withOpacity(
                                          0.1,
                                        ),
                                        child: const Icon(
                                          Icons.broken_image,
                                          size: 80,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                )
                              : Container(
                                  color: AppColors.primary.withOpacity(0.1),
                                  child: const Icon(
                                    Icons.image,
                                    size: 100,
                                    color: AppColors.primary,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _pages[index]['title']!,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _pages[index]['description']!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  if (_currentPage < _pages.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  _currentPage == _pages.length - 1
                      ? "C'EST PARTI !"
                      : "SUIVANT",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            if (_currentPage < _pages.length - 1)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Passer",
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

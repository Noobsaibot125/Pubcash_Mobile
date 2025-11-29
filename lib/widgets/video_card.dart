import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/promotion.dart';
import '../utils/colors.dart';

class VideoCard extends StatelessWidget {
  final Promotion promotion;
  // Ces paramètres sont gardés pour ne pas casser l'appel dans HomeScreen,
  // mais ils ne sont plus utilisés ici car tout se passe dans le FullScreen.
  final VoidCallback onLiked;
  final VoidCallback onShared;
  final VoidCallback onViewed;
  final bool isLiked;

  const VideoCard({
    super.key,
    required this.promotion,
    required this.onLiked,
    required this.onShared,
    required this.onViewed,
    this.isLiked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === ZONE IMAGE (MINIATURE) ===
          Stack(
            alignment: Alignment.center,
            children: [
              // 1. L'image de fond
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: promotion.thumbnailUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.video_library, color: Colors.grey, size: 50),
                    ),
                  ),
                ),
              ),

              // 2. Overlay sombre pour faire ressortir le bouton play
              Container(
                height: 200, // Ajusté implicitement par l'AspectRatio
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  color: Colors.black.withOpacity(0.2),
                ),
              ),

              // 3. Gros bouton Play (Non cliquable, juste décoratif car c'est la Card qui est cliquable)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 40),
              ),

              // 4. Badge Récompense (En haut à droite)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green, // Vert argent
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
                    ],
                  ),
                  child: Text(
                    '+${promotion.remunerationPack}F',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              
              // 5. Badge Durée (En bas à gauche)
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${promotion.duree}s',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // === ZONE INFOS (TITRE) ===
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        promotion.titre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  promotion.description ?? "Regardez la vidéo pour gagner des points.",
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 12),
                
                // Indicateur visuel "Cliquer pour regarder"
                Row(
                  children: [
                    Icon(Icons.touch_app, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      "Touchez pour regarder",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TripCover extends StatelessWidget {
  const TripCover({
    super.key,
    required this.kicker,
    required this.title,
    this.onEdit,
    this.imageAsset = 'assets/coastal-road.jpg',
    this.imageLabel = 'Camino costero entre montañas y el océano',
    this.imageAlignment = Alignment.center,
  });

  final String kicker;
  final String title;
  final VoidCallback? onEdit;
  final String imageAsset;
  final String imageLabel;
  final Alignment imageAlignment;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 148,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              imageAsset,
              fit: BoxFit.cover,
              alignment: imageAlignment,
              semanticLabel: imageLabel,
              errorBuilder: (context, error, stack) => const ColoredBox(color: forest),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x660A140F), Color(0xCC0A140F)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.explore_outlined, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          kicker,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (onEdit != null)
                        TextButton(
                          onPressed: onEdit,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Editar viaje', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: displayFamily,
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

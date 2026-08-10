import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double iconSize;
  final double titleFontSize;
  final bool showTagline;

  const AppLogo({
    super.key,
    this.iconSize = 64.0,
    this.titleFontSize = 26.0,
    this.showTagline = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cupcake Icon
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: AppColors.primaireClair.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.cake_outlined,
            size: iconSize * 0.6,
            color: AppColors.primaire,
          ),
        ),
        const SizedBox(height: 12),
        // Title: Les Délices
        Text(
          'Les Délices',
          style: GoogleFonts.caveat(
            fontSize: titleFontSize * 1.3,
            fontWeight: FontWeight.bold,
            color: AppColors.primaire,
          ),
        ),
        // Subtitle: DE L'ARTISANE
        Text(
          "DE L'ARTISANE",
          style: GoogleFonts.poppins(
            fontSize: titleFontSize * 0.45,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.5,
            color: AppColors.texte,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 10),
          Text(
            'Le goût du fait maison',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.secondaire,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

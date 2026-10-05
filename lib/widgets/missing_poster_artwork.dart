import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/missing_poster.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';

/// Public content shared with the image and printable poster.
class MissingPosterArtwork extends StatelessWidget {
  const MissingPosterArtwork({super.key, required this.poster});
  final MissingPoster poster;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      boxShadow: [
        BoxShadow(
          color: AppColors.textDark.withValues(alpha: .10),
          offset: const Offset(0, 5),
          blurRadius: 12,
        ),
      ],
      border: Border.all(color: AppColors.error, width: 2),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.pawPrint, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  poster.isActive ? 'PROCURA-SE' : 'BUSCA ENCERRADA',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: 1.3,
            child: poster.photoBytes != null
                ? Image.memory(poster.photoBytes!, fit: BoxFit.contain)
                : poster.photoPath.isNotEmpty
                ? CatPhotoView(poster.photoPath, fit: BoxFit.contain)
                : const ColoredBox(
                    color: AppColors.cardBackground,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.imageOff,
                            color: AppColors.textMedium,
                            size: 32,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Foto indisponível',
                            style: TextStyle(color: AppColors.textMedium),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          poster.displayName,
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textTitle,
          ),
        ),
        if (poster.dateLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              poster.dateLabel!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.errorText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        if (poster.includes('address') && poster.address != null)
          PosterDetailRow(
            icon: LucideIcons.mapPin,
            label: 'Último local visto',
            value: poster.address ?? 'Endereço não informado',
          ),
        for (final field in poster.characteristics.entries)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: PosterDetailRow(
              icon: field.key == 'Microchip'
                  ? LucideIcons.scanLine
                  : LucideIcons.tag,
              label: field.key,
              value: field.value,
            ),
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (poster.contacts.isEmpty)
                const PosterDetailRow(
                  icon: LucideIcons.messageCircle,
                  label: 'Fale com o tutor',
                  value: 'Pelo chat do Gatálogo',
                ),
              for (final contact in poster.contacts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: PosterDetailRow(
                    icon: LucideIcons.phone,
                    label: contact['whatsapp'] == true
                        ? 'Telefone / WhatsApp'
                        : 'Telefone',
                    value: contact['phone'] as String,
                    emphasized: true,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        if (poster.includes('qr_code'))
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: 'QR code com os detalhes públicos da busca',
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(5),
                  child: QrImageView(
                    data: poster.qrPayload,
                    size: 84,
                    padding: EdgeInsets.zero,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.textDark,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Viu este gatinho?',
                      style: GoogleFonts.fredoka(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('Fotografe pelo Gatálogo e ajude na busca.'),
                    const SizedBox(height: 6),
                    const Text(
                      'Escaneie para ver os detalhes.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

class PosterDetailRow extends StatelessWidget {
  const PosterDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });
  final IconData icon;
  final String label, value;
  final bool emphasized;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 19, color: AppColors.textMedium),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMedium,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: emphasized ? 18 : 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

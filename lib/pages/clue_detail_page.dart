import '../widgets/botanical_scene.dart';
import '../widgets/game_components.dart';
import '../widgets/app_header_actions.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_components.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'location_page.dart';
import 'conversation_page.dart';

import '../widgets/private_clue_photo.dart';

class ClueDetailPage extends StatefulWidget {
  const ClueDetailPage({
    super.key,
    required this.clue,
    required this.report,
    required this.store,
  });
  final Map<String, dynamic> clue, report;
  final CatStore store;
  @override
  State<ClueDetailPage> createState() => _ClueDetailPageState();
}

class _ClueDetailPageState extends State<ClueDetailPage> {
  late Map<String, dynamic> _clue;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _clue = Map.of(widget.clue);
  }

  Future<void> _decide(bool confirm) async {
    if (!confirm) {
      final shouldDismiss = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          title: Text(
            'Descartar avistamento?',
            style: GoogleFonts.fredoka(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textTitle,
            ),
          ),
          content: Text(
            'Tem certeza de que este avistamento não é do seu gato? Você poderá desfazer e reabrir a pista a qualquer momento.',
            style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sim, descartar'),
            ),
          ],
        ),
      );
      if (shouldDismiss != true) return;
    }

    setState(() => _busy = true);
    try {
      final result = await ProductApiService(widget.store.sessionStore).post(
        '/vision/matches/${_clue['id']}/${confirm ? 'confirm' : 'dismiss'}',
      );
      if (mounted) setState(() => _clue.addAll(result));
    } catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reopen() async {
    setState(() => _busy = true);
    try {
      final result = await ProductApiService(widget.store.sessionStore)
          .post('/vision/matches/${_clue['id']}/reopen');
      if (mounted) {
        setState(() => _clue.addAll(result));
        showMessage(context, 'Pista reaberta com sucesso.');
      }
    } catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.store.cats.where(
      (cat) => cat.id == widget.report['cat_client_id'],
    );
    final myCat = cats.isEmpty ? null : cats.first;
    final isFriendSighting = widget.clue['conversation_id'] != null;
    final isPending =
        _clue['status'] == 'pending' && widget.report['status'] == 'active';
    final isConfirmed = _clue['status'] == 'confirmed';
    final isDismissed = _clue['status'] == 'dismissed';

    return BotanicalScaffold(
      level: BotanicalLevel.tertiary,
      mood: BotanicalMood.care,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        actions: const [AppHeaderActions()],
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderLight, width: 1.2),
            ),
            child: const Icon(
              LucideIcons.chevronLeft,
              color: AppColors.textDark,
              size: 22,
            ),
          ),
        ),
        title: Text(
          'Avistamento',
          style: GoogleFonts.fredoka(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          // Destaque Especial: Avistamento por um Amigo
          if (isFriendSighting) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.socialPurpleBg,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: AppColors.socialPurple.withValues(alpha: 0.5),
                  width: 1.4,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.heartHandshake,
                          color: AppColors.socialPurpleText,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Avistado por um Amigo!',
                              style: GoogleFonts.fredoka(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.socialPurpleText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Um amigo da sua rede registrou esta foto e pode fornecer detalhes cruciais sobre onde o gatinho estava.',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.socialPurpleText,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ConversationPage(
                            sessionStore: widget.store.sessionStore,
                            conversationId:
                                widget.clue['conversation_id'] as String,
                          ),
                        ),
                      ),
                      icon: const Icon(LucideIcons.messageCircle, size: 16),
                      label: const Text('Conversar no Chat com seu Amigo'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Card: Foto do Gato Avistado
          GatalogoCard(
            backgroundColor: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GatalogoArt.image(
                      'icons/icon_camera_cream_coral',
                      width: 38,
                      height: 42,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Foto do Avistamento',
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTitle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                GamePhotoMount(
                  child: PrivateCluePhoto(
                    path: widget.clue['photo_url'] as String,
                    session: widget.store.sessionStore,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.clock,
                      size: 14,
                      color: AppColors.textMedium,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Visto em ${displayDate(widget.clue['created_at'])}, a ~${((widget.clue['distance_meters'] as num) / 1000).toStringAsFixed(1)} km do ponto de busca.',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.clue['note'] != null &&
                    (widget.clue['note'] as String).trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          LucideIcons.fileText,
                          size: 14,
                          color: AppColors.textMedium,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Observação: "${widget.clue['note']}"',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (widget.clue['latitude'] != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 14,
                      ),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LocationPage(
                          initial: LatLng(
                            (widget.clue['latitude'] as num).toDouble(),
                            (widget.clue['longitude'] as num).toDouble(),
                          ),
                          readOnly: true,
                        ),
                      ),
                    ),
                    icon: const Icon(LucideIcons.mapPin, size: 16),
                    label: const Text('Ver Ponto no Mapa'),
                  ),
                ],
              ],
            ),
          ),

          // Comparação com o gato cadastrado
          if (myCat != null) ...[
            const SizedBox(height: AppSpacing.md),
            GatalogoCard(
              backgroundColor: AppColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.pets,
                        size: 18,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Comparar com ${myCat.displayName}',
                          style: GoogleFonts.fredoka(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTitle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => showFullscreenImage(
                      context,
                      imagePath: myCat.photoPath,
                      title: myCat.displayName,
                    ),
                    child: GamePhotoMount(
                      child: CatPhotoView(
                        myCat.photoPath,
                        height: 240,
                        fit: BoxFit.contain,
                        borderRadius: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Decisão de reconhecimento
          if (isPending) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Este é o seu gato?',
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Reconhecer uma pista ajuda a registrar o histórico de localização.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.greenProgress,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _busy ? null : () => _decide(true),
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: const Text('É meu gato!'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMedium,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _busy ? null : () => _decide(false),
                    icon: const Icon(LucideIcons.x, size: 16),
                    label: const Text('Não é ele'),
                  ),
                ),
              ],
            ),
          ],
          if (isDismissed) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.xCircle,
                        size: 20,
                        color: AppColors.textMedium,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Pista Descartada',
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Você indicou anteriormente que este gato não é o seu. Se mudou de ideia ou quer reavaliar com mais calma, você pode desfazer o descarte a qualquer momento.',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _busy ? null : _reopen,
                      icon: const Icon(LucideIcons.undo, size: 16),
                      label: const Text('Desfazer descarte / Reabrir pista'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isConfirmed) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: AppColors.greenProgress.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.checkCircle,
                        size: 20,
                        color: AppColors.greenProgress,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Pista Reconhecida',
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.greenProgress,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Você confirmou que este avistamento é do seu gato. O ponto foi registrado no histórico e mapa consolidado da busca.',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMedium,
                      ),
                      onPressed: _busy ? null : _reopen,
                      icon: const Icon(LucideIcons.undo, size: 14),
                      label: const Text('Mudar de ideia / Reabrir análise'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

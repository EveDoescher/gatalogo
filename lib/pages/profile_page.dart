import '../widgets/milestone_widgets.dart';
import '../widgets/botanical_scene.dart';
import '../widgets/app_header_actions.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/product_api_service.dart';
import '../services/social_api_service.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_gamification.dart';
import '../widgets/game_components.dart';
import '../widgets/illustrated_home_components.dart';
import '../widgets/avatar_choice_sheet.dart';
import 'auth_page.dart';
import 'cat_details_page.dart';
import 'journey_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.sessionStore, this.catStore});

  final SessionStore sessionStore;
  final CatStore? catStore;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final SocialApiService _socialApi;
  late final ProductApiService _productApi;

  Map<String, dynamic>? _account;
  bool _loading = false;
  bool _busy = false;
  String? _avatarUrl;
  String? _localPreviewPath;
  String _userBio = '';
  int _friendsCount = 0;

  @override
  void initState() {
    super.initState();
    _socialApi = SocialApiService(widget.sessionStore);
    _productApi = ProductApiService(widget.sessionStore);
    _load();
  }

  Future<void> _load() async {
    if (!widget.sessionStore.isSignedIn) return;
    setState(() => _loading = true);
    try {
      final accountData = await _productApi.get('/app/account');
      List<Map<String, dynamic>> friendsData = [];
      try {
        friendsData = await _socialApi.friends();
      } catch (_) {}

      try {
        await widget.catStore?.refreshGamification();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _account = accountData;
          _userBio = (accountData['bio'] as String?) ?? '';
          _avatarUrl = accountData['avatar_url'] as String?;
          _friendsCount = friendsData.length;
        });
        if (_avatarUrl != widget.sessionStore.avatarUrl) {
          widget.sessionStore.updateAvatarUrl(_avatarUrl);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _ensureSignedIn(String action) async {
    if (widget.sessionStore.isSignedIn) return true;
    final doSignIn = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        title: Text(
          'Conta necessaria',
          style: GoogleFonts.fredoka(
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
        content: Text(
          'Para $action, entre ou crie uma conta gratuita no Gatalogo.',
          style: GoogleFonts.nunito(color: AppColors.textDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Agora nao',
              style: GoogleFonts.nunito(
                color: AppColors.textMedium,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Entrar ou Cadastrar',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (doSignIn == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AuthPage(
            sessionStore: widget.sessionStore,
            onContinueOffline: () => Navigator.pop(context),
          ),
        ),
      );
      if (widget.sessionStore.isSignedIn) {
        await _load();
        return true;
      }
    }
    return false;
  }

  Future<void> _pickProfilePhoto() async {
    if (_busy) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeArt.paper,
      builder: (_) =>
          AvatarChoiceSheet(currentUrl: widget.sessionStore.avatarUrl),
    );
    if (choice == null || !mounted) return;
    if (FramedUserAvatar.presets.contains(choice)) {
      setState(() => _busy = true);
      try {
        var url = '/app/account/avatar/preset/$choice';
        if (widget.sessionStore.isSignedIn) {
          final saved = await _productApi.put('/app/account', {
            'avatar_preset': choice,
          });
          url = saved['avatar_url'] as String;
        }
        await widget.sessionStore.updateAvatarUrl(url);
        if (mounted) {
          setState(() {
            _avatarUrl = url;
            _localPreviewPath = null;
          });
        }
      } catch (e) {
        if (mounted) {
          showMessage(context, 'Não foi possível salvar seu avatar: $e');
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    if (!await _ensureSignedIn('salvar sua foto de perfil') || !mounted) return;
    final source = choice == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _localPreviewPath = picked.path;
        _busy = true;
      });
      final bytes = await File(picked.path).readAsBytes();
      final uploadedUrl = await _socialApi.uploadAvatar(bytes, picked.name);
      if (uploadedUrl == null) {
        throw StateError('O envio não retornou a foto salva.');
      }
      await widget.sessionStore.updateAvatarUrl(uploadedUrl);
      if (mounted) {
        setState(() {
          _avatarUrl = uploadedUrl;
          _localPreviewPath = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _localPreviewPath = null);
        showMessage(context, 'Não foi possível enviar sua foto: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editBio() async {
    if (!await _ensureSignedIn('personalizar sua bio')) return;
    if (!mounted) return;
    final controller = TextEditingController(text: _userBio);
    final newBio = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        title: Text(
          'Mensagem de Status / Bio',
          style: GoogleFonts.fredoka(
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Escreva uma frase sobre voce ou seus gatos (salva na sua conta):',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              maxLength: 120,
              maxLines: 3,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
              decoration: InputDecoration(
                hintText: 'ex: Apaixonado por felinos...',
                filled: true,
                fillColor: AppColors.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.nunito(
                color: AppColors.textMedium,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(
              'Salvar',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (newBio == null || newBio == _userBio) return;
    setState(() => _busy = true);
    try {
      final updated = await _socialApi.updateAccount(bio: newBio);
      if (mounted) {
        setState(() {
          _userBio = (updated['bio'] as String?) ?? newBio;
        });
        showMessage(context, 'Bio atualizada com sucesso no servidor.');
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Erro ao salvar bio: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editUsername() async {
    if (!await _ensureSignedIn('alterar seu nome de usuario')) return;
    if (!mounted) return;
    final currentUsername = _account?['username'] ?? '';
    final controller = TextEditingController(text: currentUsername);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        title: Text(
          'Alterar Apelido',
          style: GoogleFonts.fredoka(
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Como seus amigos verao voce no aplicativo:',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              maxLength: 30,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
              decoration: InputDecoration(
                prefixText: '@',
                prefixStyle: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
                labelText: 'Apelido unico',
                filled: true,
                fillColor: AppColors.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.nunito(
                color: AppColors.textMedium,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(
              'Salvar',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == currentUsername) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _socialApi.updateAccount(username: newName);
      if (mounted) {
        showMessage(context, 'Apelido atualizado com sucesso.');
        await _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      widget.sessionStore,
      if (widget.catStore != null) widget.catStore!,
    ]),
    builder: (context, _) => _buildProfile(context),
  );

  Widget _buildProfile(BuildContext context) {
    final isSignedIn = widget.sessionStore.isSignedIn;
    final email = widget.sessionStore.session?.email ?? '';
    final username =
        _account?['username'] as String? ??
        (isSignedIn && email.isNotEmpty ? email.split('@').first : 'Visitante');
    final discoveries = widget.catStore?.discoveries ?? [];
    final totalCats =
        (widget.catStore?.progress.summary['confirmed_individuals'] as num?)
            ?.toInt() ??
        widget.catStore?.individuals.length ??
        0;

    final journeyList = widget.catStore != null
        ? localJourney(widget.catStore!)
        : [];
    final unlockedAchievementsCount = isSignedIn
        ? widget.catStore?.gamification.unlockedAchievements ?? 0
        : journeyList.where((item) {
            final target = (item['target'] as num?)?.toInt() ?? 1;
            final progress = (item['progress'] as num?)?.toInt() ?? 0;
            return progress >= target;
          }).length;

    return BotanicalScaffold(
      backgroundColor: GameStyle.canvas,
      appBar: AppBar(
        leadingWidth: 44,
        titleSpacing: 8,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Meu Perfil',
          style: GoogleFonts.fredoka(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
        actions: [
          const AppHeaderActions(showAvatar: false),
          IconButton(
            tooltip: 'Configurações',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Icon(
                LucideIcons.settings,
                size: 20,
                color: AppColors.textDark,
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsPage(
                  sessionStore: widget.sessionStore,
                  catStore: widget.catStore,
                ),
              ),
            ).then((_) => _load()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                Center(
                  child: IllustratedProfileIdentity(
                    portrait: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        FramedUserAvatar(
                          url: _avatarUrl ?? widget.sessionStore.avatarUrl,
                          localPath: _localPreviewPath,
                          size: 116,
                        ),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: GestureDetector(
                            onTap: _pickProfilePhoto,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.2,
                                  ),
                                ),
                                child: const Icon(
                                  LucideIcons.camera,
                                  size: 17,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    name: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '@$username',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.fredoka(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTitle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: _busy ? null : _editUsername,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoftBg,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.borderProfile,
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                LucideIcons.pencil,
                                size: 14,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                if (widget.catStore != null) ...[
                  GatalogoGamificationCard(
                    gamification: widget.catStore!.gamification,
                    onTapJourney: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JourneyPage(store: widget.catStore!),
                      ),
                    ).then((_) => _load()),
                  ),
                  const SizedBox(height: 16),
                ],

                GameNote(
                  child: Row(
                    children: [
                      GatalogoArt.image(
                        'ui/ui_note_pinned',
                        width: 38,
                        height: 38,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _userBio.isNotEmpty ? _userBio : 'Toque no lapis para adicionar uma frase ou bio ao seu perfil',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontStyle: _userBio.isNotEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: _userBio.isNotEmpty
                                ? AppColors.textDark
                                : AppColors.textMedium,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Editar bio',
                        icon: const Icon(
                          LucideIcons.pencil,
                          size: 16,
                          color: AppColors.textLight,
                        ),
                        onPressed: _editBio,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final stat in <(String, String, String)>[
                        (
                          '$totalCats',
                          'Gatos diferentes',
                          'ui/ui_cat_photos_stack',
                        ),
                        (
                          '$unlockedAchievementsCount',
                          'Conquistas',
                          'rewards/reward_medal_paw_gold',
                        ),
                        (
                          '$_friendsCount',
                          'Amigos',
                          'ui/ui_speech_ellipsis_heart',
                        ),
                      ])
                        SizedBox(
                          width: (constraints.maxWidth - 24) / 3,
                          child: IllustratedStatTile(
                            value: stat.$1,
                            label: stat.$2,
                            art: stat.$3,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (widget.catStore != null && isSignedIn)
                  GameNote(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Medalhas em destaque',
                                style: GameStyle.title(20),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JourneyPage(
                                    store: widget.catStore!,
                                    initialSection: 'achievement',
                                  ),
                                ),
                              ),
                              child: const Text('Escolher'),
                            ),
                          ],
                        ),
                        if ((widget
                                        .catStore!
                                        .progress
                                        .summary['highlighted_medals']
                                    as List? ??
                                [])
                            .isEmpty)
                          const Text(
                            'Escolha até cinco medalhas no mural para contar sua história.',
                          ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final medal in journeyList.where(
                              (g) =>
                                  (widget
                                                  .catStore!
                                                  .progress
                                                  .summary['highlighted_medals']
                                              as List? ??
                                          [])
                                      .contains(g['id']) &&
                                  g['completed'] == true,
                            ))
                              AchievementMedal(
                                goal: medal,
                                size: 70,
                                onTap: () => showAchievement(context, medal),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Suas Descobertas',
                        style: GoogleFonts.fredoka(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTitle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (discoveries.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      children: [
                        GatalogoArt.image(
                          'ui/ui_notebook_cat',
                          width: 80,
                          height: 80,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nenhum gatinho salvo ainda',
                          style: GoogleFonts.fredoka(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTitle,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tire fotos de gatinhos para preencher seu perfil de explorador!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: discoveries.take(6).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final cat = discoveries[index];
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CatDetailsPage(
                                cat: cat,
                                catStore: widget.catStore!,
                              ),
                            ),
                          ),
                          child: Container(
                            width: 100,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    height: 68,
                                    width: double.infinity,
                                    child: CatPhotoView(
                                      cat.photoPath,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  cat.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.nunito(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 30),
              ],
            ),
    );
  }
}

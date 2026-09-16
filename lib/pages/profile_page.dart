import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/api_config.dart';
import '../services/product_api_service.dart';
import '../services/social_api_service.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'auth_page.dart';
import 'cat_details_page.dart';
import 'friends_page.dart';
import 'journey_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.sessionStore,
    this.catStore,
  });

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
      // Offline mode
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
    if (!await _ensureSignedIn('alterar sua foto de perfil')) return;
    if (!mounted) return;
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alterar Foto de Perfil',
                style: GoogleFonts.fredoka(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.camera, color: AppColors.primary, size: 20),
                ),
                title: Text(
                  'Tirar Foto com a Camera',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.greenLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.image, color: AppColors.greenLink, size: 20),
                ),
                title: Text(
                  'Escolher da Galeria',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    try {
      final picked = await picker.pickImage(source: source, maxWidth: 600, maxHeight: 600);
      if (picked != null) {
        setState(() {
          _localPreviewPath = picked.path;
          _busy = true;
        });

        final bytes = await File(picked.path).readAsBytes();
        final uploadedUrl = await _socialApi.uploadAvatar(bytes, picked.name);

        if (mounted) {
          setState(() {
            if (uploadedUrl != null) _avatarUrl = uploadedUrl;
            _busy = false;
          });
          if (uploadedUrl != null) {
            await widget.sessionStore.updateAvatarUrl(uploadedUrl);
          }
          if (mounted) {
            showMessage(context, 'Foto de perfil salva com sucesso no servidor.');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, 'Erro ao enviar foto: $e');
      }
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
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMedium),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              maxLength: 120,
              maxLines: 3,
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: AppColors.textDark),
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
              style: GoogleFonts.nunito(color: AppColors.textMedium, fontWeight: FontWeight.w700),
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
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMedium),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              maxLength: 30,
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.textDark),
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
              style: GoogleFonts.nunito(color: AppColors.textMedium, fontWeight: FontWeight.w700),
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

    if (newName == null || newName.isEmpty || newName == currentUsername) return;
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
  Widget build(BuildContext context) {
    final isSignedIn = widget.sessionStore.isSignedIn;
    final email = widget.sessionStore.session?.email ?? '';
    final username = _account?['username'] as String? ??
        (isSignedIn && email.isNotEmpty ? email.split('@').first : 'Visitante');
    final discoveries = widget.catStore?.discoveries ?? [];
    final totalCats = discoveries.length;

    // Conquistas reais da jornada
    final journeyList = widget.catStore != null ? localJourney(widget.catStore!) : [];
    final unlockedAchievementsCount = journeyList.where((item) {
      final target = (item['target'] as num?)?.toInt() ?? 1;
      final progress = (item['progress'] as num?)?.toInt() ?? 0;
      return progress >= target;
    }).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
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
          IconButton(
            tooltip: 'Configurações',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Icon(LucideIcons.settings, size: 20, color: AppColors.textDark),
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // 1. Banner Decorativo e Avatar
                Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      height: 110,
                      margin: const EdgeInsets.only(top: 36),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoftBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.borderProfile.withValues(alpha: 0.5)),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: -12,
                            right: -10,
                            child: IgnorePointer(
                              child: Image.asset(
                                'assets/images/Folha_1.png',
                                width: 85,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -10,
                            left: 10,
                            child: IgnorePointer(
                              child: Transform.rotate(
                                angle: 1.2,
                                child: Image.asset(
                                  'assets/images/Folha_2.png',
                                  width: 70,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Avatar Central
                    Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.surface,
                                border: Border.all(color: AppColors.primary, width: 3),
                              ),
                              child: ClipOval(
                                child: _localPreviewPath != null
                                    ? Image.file(
                                        File(_localPreviewPath!),
                                        width: 104,
                                        height: 104,
                                        fit: BoxFit.cover,
                                      )
                                    : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                        ? Image.network(
                                            _avatarUrl!.startsWith('http')
                                                ? _avatarUrl!
                                                : '${ApiConfig.baseUrl}$_avatarUrl',
                                            width: 104,
                                            height: 104,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Image.asset(
                                              'assets/images/gato_1.png',
                                              width: 104,
                                              height: 104,
                                              fit: BoxFit.contain,
                                            ),
                                          )
                                        : Image.asset(
                                            'assets/images/gato_1.png',
                                            width: 104,
                                            height: 104,
                                            fit: BoxFit.contain,
                                          ),
                              ),
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
                                      border: Border.all(color: Colors.white, width: 2.2),
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
                        const SizedBox(height: 10),

                        // Nome de Usuário (@username)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '@$username',
                              style: GoogleFonts.fredoka(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textTitle,
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
                                    border: Border.all(color: AppColors.borderProfile, width: 1),
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
                        const SizedBox(height: 2),

                        // Indicador de Explorador Ativo
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.greenLight,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.pets, size: 12, color: AppColors.greenProgress),
                              const SizedBox(width: 6),
                              Text(
                                totalCats == 0
                                    ? 'Novo Explorador'
                                    : '$totalCats ${totalCats == 1 ? "gato catalogado" : "gatos catalogados"}',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.greenLink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 2. Card de Bio / Status (Salvo na API)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.quote, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _userBio.isNotEmpty
                              ? _userBio
                              : 'Toque no lapis para adicionar uma frase ou bio ao seu perfil',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontStyle: _userBio.isNotEmpty ? FontStyle.italic : FontStyle.normal,
                            color: _userBio.isNotEmpty ? AppColors.textDark : AppColors.textMedium,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Editar bio',
                        icon: const Icon(LucideIcons.pencil, size: 16, color: AppColors.textLight),
                        onPressed: _editBio,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 3. Vitrine de Estatísticas Reais
                Row(
                  children: [
                    // Gatos Catalogados
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.pets, size: 22, color: AppColors.primary),
                            const SizedBox(height: 4),
                            Text(
                              '$totalCats',
                              style: GoogleFonts.fredoka(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textTitle,
                              ),
                            ),
                            Text(
                              'Gatos Salvos',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Troféus da Jornada (Reais)
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.catStore != null
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => JourneyPage(store: widget.catStore!),
                                  ),
                                )
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppColors.achievementBg,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(
                              color: AppColors.achievement.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(LucideIcons.trophy, size: 22, color: AppColors.achievementDark),
                              const SizedBox(height: 4),
                              Text(
                                '$unlockedAchievementsCount/${journeyList.length}',
                                style: GoogleFonts.fredoka(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.achievementText,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Conquistas',
                                    style: GoogleFonts.nunito(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.achievementText,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(LucideIcons.chevronRight, size: 10, color: AppColors.achievementText),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Amigos Conectados (Reais da API)
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          if (!await _ensureSignedIn('acessar a lista de amigos')) return;
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FriendsPage(sessionStore: widget.sessionStore),
                            ),
                          ).then((_) => _load());
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppColors.socialPurpleBg,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(
                              color: AppColors.socialPurple.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(LucideIcons.users, size: 22, color: AppColors.socialPurpleText),
                              const SizedBox(height: 4),
                              Text(
                                '$_friendsCount',
                                style: GoogleFonts.fredoka(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.socialPurpleText,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Amigos',
                                    style: GoogleFonts.nunito(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.socialPurpleText,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(LucideIcons.chevronRight, size: 10, color: AppColors.socialPurpleText),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // 4. Suas Descobertas Recentes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Suas Descobertas',
                      style: GoogleFonts.fredoka(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTitle,
                      ),
                    ),
                    if (totalCats > 0)
                      Text(
                        '$totalCats no catálogo',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
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
                        Image.asset('assets/images/gato_2.png', width: 70),
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
                          style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMedium),
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
                              borderRadius: BorderRadius.circular(AppRadius.card),
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
                                    child: CatPhotoView(cat.photoPath, fit: BoxFit.cover),
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

                const SizedBox(height: 24),

                // 5. Card com Detalhes da Conta ou Modo Visitante
                if (isSignedIn)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: AppColors.primarySoftBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.mail, size: 18, color: AppColors.primaryDark),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Conta Conectada',
                                style: GoogleFonts.fredoka(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTitle,
                                ),
                              ),
                              Text(
                                email,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(LucideIcons.checkCircle2, size: 18, color: AppColors.greenProgress),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: AppColors.cardAltBackground,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.user, size: 18, color: AppColors.textMedium),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Modo Visitante',
                                    style: GoogleFonts.fredoka(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textTitle,
                                    ),
                                  ),
                                  Text(
                                    'Suas descobertas estao salvas neste aparelho. Crie uma conta para salvar na nuvem.',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      color: AppColors.textMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AuthPage(
                                  sessionStore: widget.sessionStore,
                                  onContinueOffline: () => Navigator.pop(context),
                                ),
                              ),
                            ).then((_) {
                              if (widget.sessionStore.isSignedIn) {
                                _load();
                              }
                            }),
                            child: Text(
                              'Entrar ou Criar Conta',
                              style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 30),
              ],
            ),
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_components.dart';
import 'auth_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.sessionStore,
    this.catStore,
  });

  final SessionStore sessionStore;
  final CatStore? catStore;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _account;
  PackageInfo? _packageInfo;
  bool _loading = false;
  bool _busy = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    }).catchError((_) {});
  }

  Future<void> _load() async {
    if (!widget.sessionStore.isSignedIn) return;
    setState(() => _loading = true);
    try {
      final data = await ProductApiService(widget.sessionStore).get('/app/account');
      if (mounted) {
        setState(() {
          _account = data;
        });
      }
    } catch (_) {
      // Modo offline mantém estado anterior
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePreference(String key, bool value) async {
    if (_account == null) return;
    setState(() => _busy = true);
    try {
      final preferences = Map<String, dynamic>.from(
        _account!['preferences'] as Map? ?? {},
      )..[key] = value;

      await ProductApiService(widget.sessionStore).request(
        'PUT',
        '/app/preferences',
        preferences,
      );
      if (mounted) {
        setState(() => _account!['preferences'] = preferences);
        showMessage(context, 'Preferência salva!');
      }
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _triggerManualSync() async {
    if (widget.catStore == null) return;
    setState(() => _syncing = true);
    try {
      await widget.catStore!.syncCatalog();
      await widget.catStore!.syncPendingAnalyses();
      if (mounted) {
        showMessage(context, 'Sincronizacao concluida com sucesso.');
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Erro ao sincronizar: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await confirmAction(
      context,
      'Sair da conta?',
      'Seus dados sincronizados continuarão salvos na nuvem. Você poderá entrar novamente a qualquer momento.',
      'Sair',
    );
    if (!confirmed) return;

    try {
      await widget.sessionStore.logout();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  Future<void> _showDeactivationDialog() async {
    final email = widget.sessionStore.session?.email ?? '';
    final codeController = TextEditingController();
    bool codeSent = false;
    bool sendingCode = false;
    bool confirming = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.dialog),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.errorBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.alertTriangle,
                    color: AppColors.error,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Desativar Conta',
                    style: GoogleFonts.fredoka(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTitle,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Por motivos de seguranca, a desativacao da conta exige confirmacao por codigo enviado ao seu e-mail cadastrado.',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.mail, size: 16, color: AppColors.textMedium),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            email.isNotEmpty ? email : 'E-mail cadastrado',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.errorBg,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        errorMessage!,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.errorText,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (!codeSent)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: const BorderSide(color: AppColors.borderProfile),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: sendingCode
                            ? null
                            : () async {
                                setDialogState(() {
                                  sendingCode = true;
                                  errorMessage = null;
                                });
                                try {
                                  await widget.sessionStore.requestDeactivationCode();
                                  setDialogState(() {
                                    codeSent = true;
                                    sendingCode = false;
                                  });
                                } catch (e) {
                                  setDialogState(() {
                                    sendingCode = false;
                                    errorMessage = e.toString().replaceFirst('Exception: ', '');
                                  });
                                }
                              },
                        icon: sendingCode
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(LucideIcons.send, size: 16),
                        label: Text(
                          sendingCode ? 'Enviando codigo...' : 'Enviar Codigo para meu E-mail',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.greenLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.checkCircle, size: 16, color: AppColors.greenLink),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Codigo de 6 digitos enviado! Verifique sua caixa de entrada.',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.greenLink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 22,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textTitle,
                      ),
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle: GoogleFonts.nunito(
                          fontSize: 20,
                          letterSpacing: 6,
                          color: AppColors.textLight,
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
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
              if (codeSent)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  onPressed: confirming
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.length != 6) {
                            setDialogState(() {
                              errorMessage = 'Informe os 6 digitos do codigo de confirmacao.';
                            });
                            return;
                          }
                          setDialogState(() {
                            confirming = true;
                            errorMessage = null;
                          });
                          try {
                            await widget.sessionStore.confirmDeactivate(code: code);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          } catch (e) {
                            setDialogState(() {
                              confirming = false;
                              errorMessage = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: confirming
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Confirmar Desativacao',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool loading = false;
    String? errorMsg;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.dialog),
            ),
            title: Row(
              children: [
                const Icon(LucideIcons.lock, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Alterar Senha',
                  style: GoogleFonts.fredoka(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha Atual',
                      prefixIcon: Icon(LucideIcons.keyRound, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nova Senha (min. 6 caracteres)',
                      prefixIcon: Icon(LucideIcons.lock, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar Nova Senha',
                      prefixIcon: Icon(LucideIcons.check, size: 18),
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMsg!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        final cur = currentPasswordController.text;
                        final newP = newPasswordController.text;
                        final conf = confirmPasswordController.text;
                        if (cur.isEmpty) {
                          setDialogState(() => errorMsg = 'Informe a senha atual.');
                          return;
                        }
                        if (newP.length < 6) {
                          setDialogState(() => errorMsg = 'A nova senha deve ter no minimo 6 caracteres.');
                          return;
                        }
                        if (newP != conf) {
                          setDialogState(() => errorMsg = 'As novas senhas nao coincidem.');
                          return;
                        }

                        setDialogState(() {
                          loading = true;
                          errorMsg = null;
                        });

                        try {
                          await ProductApiService(widget.sessionStore).post(
                            '/auth/change-password',
                            {'current_password': cur, 'new_password': newP},
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            showMessage(context, 'Senha alterada com sucesso!');
                          }
                        } catch (e) {
                          setDialogState(() {
                            loading = false;
                            errorMsg = e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      },
                child: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showChangeEmailDialog() async {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    bool codeSent = false;
    bool loading = false;
    String? errorMsg;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.dialog),
            ),
            title: Row(
              children: [
                const Icon(LucideIcons.mail, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Alterar E-mail',
                  style: GoogleFonts.fredoka(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    codeSent
                        ? 'Um codigo de confirmacao foi enviado para ${emailController.text.trim()}. Digite-o abaixo:'
                        : 'Digite o novo endereco de e-mail. Enviaremos um codigo de verificacao para confirmar a troca.',
                    style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMedium),
                  ),
                  const SizedBox(height: 16),
                  if (!codeSent)
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Novo E-mail',
                        prefixIcon: Icon(LucideIcons.atSign, size: 18),
                      ),
                    )
                  else
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Codigo de 6 digitos',
                        prefixIcon: Icon(LucideIcons.keyRound, size: 18),
                      ),
                    ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMsg!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        if (!codeSent) {
                          if (email.isEmpty || !email.contains('@')) {
                            setDialogState(() => errorMsg = 'Informe um e-mail valido.');
                            return;
                          }
                          setDialogState(() {
                            loading = true;
                            errorMsg = null;
                          });
                          try {
                            await ProductApiService(widget.sessionStore).post(
                              '/auth/change-email/request',
                              {'new_email': email},
                            );
                            setDialogState(() {
                              loading = false;
                              codeSent = true;
                            });
                          } catch (e) {
                            setDialogState(() {
                              loading = false;
                              errorMsg = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        } else {
                          final code = codeController.text.trim();
                          if (code.length != 6) {
                            setDialogState(() => errorMsg = 'Digite o codigo de 6 digitos.');
                            return;
                          }
                          setDialogState(() {
                            loading = true;
                            errorMsg = null;
                          });
                          try {
                            await ProductApiService(widget.sessionStore).post(
                              '/auth/change-email/confirm',
                              {'new_email': email, 'code': code},
                            );
                            await widget.sessionStore.updateEmail(email);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              setState(() {
                                if (_account != null) _account!['email'] = email;
                              });
                              showMessage(context, 'E-mail alterado com sucesso!');
                            }
                          } catch (e) {
                            setDialogState(() {
                              loading = false;
                              errorMsg = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        }
                      },
                child: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(codeSent ? 'Confirmar' : 'Enviar Codigo'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportUserData() async {
    setState(() => _busy = true);
    try {
      final data = await ProductApiService(widget.sessionStore).get('/app/account/export');
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      await SharePlus.instance.share(
        ShareParams(
          text: jsonString,
          subject: 'Gatalogo - Exportacao de Dados Pessoais (LGPD)',
        ),
      );
      if (mounted) {
        showMessage(context, 'Dados exportados com sucesso!');
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Erro ao exportar dados: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showFeedbackDialog() async {
    final messageController = TextEditingController();
    String category = 'sugestao';
    bool loading = false;
    String? errorMsg;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.dialog),
            ),
            title: Row(
              children: [
                const Icon(LucideIcons.messageSquare, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Feedback & Suporte',
                  style: GoogleFonts.fredoka(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selecione o tipo de mensagem:',
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        label: const Text('Sugestao'),
                        selected: category == 'sugestao',
                        onSelected: (val) => setDialogState(() => category = 'sugestao'),
                      ),
                      ChoiceChip(
                        label: const Text('Problema/Bug'),
                        selected: category == 'bug',
                        onSelected: (val) => setDialogState(() => category = 'bug'),
                      ),
                      ChoiceChip(
                        label: const Text('Elogio'),
                        selected: category == 'elogio',
                        onSelected: (val) => setDialogState(() => category = 'elogio'),
                      ),
                      ChoiceChip(
                        label: const Text('Outro'),
                        selected: category == 'outro',
                        onSelected: (val) => setDialogState(() => category = 'outro'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Conte em detalhes o que aconteceu ou a sua sugestao...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMsg!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        final msg = messageController.text.trim();
                        if (msg.isEmpty) {
                          setDialogState(() => errorMsg = 'Por favor, digite sua mensagem.');
                          return;
                        }
                        setDialogState(() {
                          loading = true;
                          errorMsg = null;
                        });
                        try {
                          await ProductApiService(widget.sessionStore).post(
                            '/app/feedback',
                            {
                              'category': category,
                              'message': msg,
                              'device_info': 'Gatalogo App Mobile Flutter',
                            },
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            showMessage(context, 'Feedback enviado com sucesso! Muito obrigado!');
                          }
                        } catch (e) {
                          setDialogState(() {
                            loading = false;
                            errorMsg = e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      },
                child: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enviar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAppLicenses() {
    final versionStr = _packageInfo != null
        ? 'v${_packageInfo!.version} (${_packageInfo!.buildNumber})'
        : '1.0.0';
    showLicensePage(
      context: context,
      applicationName: 'Gatálogo',
      applicationVersion: versionStr,
      applicationLegalese: '© 2026 Gatálogo Team - Feito com amor para amantes de gatos.',
      applicationIcon: Padding(
        padding: const EdgeInsets.all(12),
        child: Image.asset('assets/images/Logo.png', height: 48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = (_account?['preferences'] as Map?) ?? {};
    final sightingPush = prefs['sighting_notifications'] != false;
    final socialPush = prefs['social_notifications'] != false;

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
          'Configurações',
          style: GoogleFonts.fredoka(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              children: [
                if (!widget.sessionStore.isSignedIn) ...[
                  GatalogoCard(
                    backgroundColor: AppColors.primaryLight.withValues(alpha: 0.35),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.userX, color: AppColors.primary, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Modo Convidado',
                              style: GoogleFonts.fredoka(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Crie uma conta gratuita ou entre para sincronizar seus gatos na nuvem, compartilhar com amigos e nunca perder seus registros.',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: AppColors.textDark,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AuthPage(
                                    sessionStore: widget.sessionStore,
                                    onContinueOffline: () => Navigator.pop(context),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(LucideIcons.logIn, size: 18),
                            label: const Text('Criar Conta ou Entrar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // 1. Sincronização & Nuvem
                Text(
                  'Sincronização & Dados',
                  style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GatalogoCard(
                  backgroundColor: AppColors.surface,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.greenLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.cloud,
                              color: AppColors.greenLink,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Catálogo em Nuvem',
                                  style: GoogleFonts.fredoka(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  widget.catStore != null
                                      ? '${widget.catStore!.discoveries.length} gatos salvos no dispositivo'
                                      : 'Sincronização ativa',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    color: AppColors.textMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _syncing ? null : _triggerManualSync,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.greenButton,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                            ),
                            child: _syncing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Sincronizar',
                                    style: GoogleFonts.nunito(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (widget.sessionStore.isSignedIn) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Segurança & Privacidade',
                    style: GoogleFonts.fredoka(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTitle,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  GatalogoCard(
                    backgroundColor: AppColors.surface,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ListTile(
                          onTap: _showChangePasswordDialog,
                          leading: const Icon(
                            LucideIcons.lock,
                            color: AppColors.primaryDark,
                            size: 20,
                          ),
                          title: Text(
                            'Alterar Senha',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          subtitle: Text(
                            'Atualize a sua senha de acesso.',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: AppColors.textMedium,
                            ),
                          ),
                          trailing: const Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: AppColors.textLight,
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.borderLight),
                        ListTile(
                          onTap: _showChangeEmailDialog,
                          leading: const Icon(
                            LucideIcons.mail,
                            color: AppColors.primaryDark,
                            size: 20,
                          ),
                          title: Text(
                            'Alterar E-mail',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          subtitle: Text(
                            widget.sessionStore.session?.email ?? 'Atualize seu endereco cadastrado.',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: AppColors.textMedium,
                            ),
                          ),
                          trailing: const Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: AppColors.textLight,
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.borderLight),
                        ListTile(
                          onTap: _busy ? null : _exportUserData,
                          leading: const Icon(
                            LucideIcons.downloadCloud,
                            color: AppColors.primaryDark,
                            size: 20,
                          ),
                          title: Text(
                            'Exportar Meus Dados (LGPD)',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          subtitle: Text(
                            'Baixe uma copia aberta (JSON) dos seus gatos, avistamentos e perfil.',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: AppColors.textMedium,
                            ),
                          ),
                          trailing: const Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                // 2. Notificações
                Text(
                  'Notificações & Avisos',
                  style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GatalogoCard(
                  backgroundColor: AppColors.surface,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: sightingPush,
                        onChanged: _busy
                            ? null
                            : (val) => _updatePreference(
                                  'sighting_notifications',
                                  val,
                                ),
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primaryLight,
                        title: Text(
                          'Avistamentos e gatos perdidos',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        subtitle: Text(
                          'Receba alertas quando um gato for avistado perto de você.',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.borderLight),
                      SwitchListTile(
                        value: socialPush,
                        onChanged: _busy
                            ? null
                            : (val) => _updatePreference(
                                  'social_notifications',
                                  val,
                                ),
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primaryLight,
                        title: Text(
                          'Amigos e mensagens',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        subtitle: Text(
                          'Notificações quando amigos mandarem mensagens ou desbloquearem conquistas.',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // 3. Feedback & Suporte
                Text(
                  'Feedback & Ajuda',
                  style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GatalogoCard(
                  backgroundColor: AppColors.surface,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        onTap: _showFeedbackDialog,
                        leading: const Icon(
                          LucideIcons.messageSquare,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                        title: Text(
                          'Enviar Feedback ou Relatar Problema',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        subtitle: Text(
                          'Envie sugestoes, elogios ou reporte bugs diretamente ao time.',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.textMedium,
                          ),
                        ),
                        trailing: const Icon(
                          LucideIcons.chevronRight,
                          size: 18,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // 4. Sobre o Gatálogo & Licenças
                Text(
                  'Sobre o Aplicativo',
                  style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GatalogoCard(
                  backgroundColor: AppColors.surface,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          LucideIcons.info,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                        title: Text(
                          'Versão do Gatálogo',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        trailing: Text(
                          _packageInfo != null
                              ? 'v${_packageInfo!.version} (${_packageInfo!.buildNumber})'
                              : 'v1.0.0',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.borderLight),
                      ListTile(
                        onTap: _showAppLicenses,
                        leading: const Icon(
                          LucideIcons.fileText,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                        title: Text(
                          'Licenças de Código Aberto',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        subtitle: Text(
                          'Bibliotecas e tecnologias que tornam o Gatálogo possível.',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.textMedium,
                          ),
                        ),
                        trailing: const Icon(
                          LucideIcons.chevronRight,
                          size: 18,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // 4. Zona de Risco (Sair e Desativar Conta)
                Text(
                  'Conta & Sessão',
                  style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GatalogoCard(
                  backgroundColor: AppColors.surface,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        onTap: _logout,
                        leading: const Icon(
                          LucideIcons.logOut,
                          color: AppColors.textMedium,
                          size: 20,
                        ),
                        title: Text(
                          'Sair da conta',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        subtitle: Text(
                          'Encerrar sessão neste dispositivo.',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.textMedium,
                          ),
                        ),
                        trailing: const Icon(
                          LucideIcons.chevronRight,
                          size: 18,
                          color: AppColors.textLight,
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.borderLight),
                      ListTile(
                        onTap: _showDeactivationDialog,
                        leading: const Icon(
                          LucideIcons.trash2,
                          color: AppColors.error,
                          size: 20,
                        ),
                        title: Text(
                          'Desativar conta',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                        subtitle: Text(
                          'Requer validação segura por código de e-mail.',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.textMedium,
                          ),
                        ),
                        trailing: const Icon(
                          LucideIcons.chevronRight,
                          size: 18,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
    );
  }
}
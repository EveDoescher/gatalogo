import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/auth_api_service.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';

enum _AuthMode {
  login,
  register,
  verify,
  resetRequest,
  resetVerify,
  resetConfirm,
}

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.sessionStore,
    required this.onContinueOffline,
    this.startWithRecovery = false,
    this.initialEmail,
  });

  final SessionStore sessionStore;
  final VoidCallback onContinueOffline;
  final bool startWithRecovery;
  final String? initialEmail;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirmation = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  _AuthMode _mode = _AuthMode.login;
  String? _error;
  String? _resetToken;
  int _resendSeconds = 0;
  Timer? _timer;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    widget.sessionStore.addListener(_sessionChanged);
    _email.text = widget.initialEmail ?? '';
    if (widget.startWithRecovery) _mode = _AuthMode.resetRequest;
  }

  void _sessionChanged() {
    if (!widget.startWithRecovery &&
        widget.sessionStore.isSignedIn &&
        mounted &&
        Navigator.of(context).canPop()) {
      Navigator.pop(context);
    }
  }

  void _cooldown() {
    _timer?.cancel();
    _resendSeconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    try {
      if (_mode == _AuthMode.verify) {
        await widget.sessionStore.resendVerification(_email.text);
      } else {
        await widget.sessionStore.requestPasswordReset(_email.text);
      }
      if (mounted) {
        setState(() => _error = null);
        _cooldown();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  bool get _needsPassword =>
      _mode == _AuthMode.login ||
      _mode == _AuthMode.register ||
      _mode == _AuthMode.resetConfirm;

  bool get _needsCode =>
      _mode == _AuthMode.verify || _mode == _AuthMode.resetVerify;

  bool get _showsEmail =>
      _mode != _AuthMode.verify &&
      _mode != _AuthMode.resetVerify &&
      _mode != _AuthMode.resetConfirm;

  String get _otpCode =>
      _otpControllers.map((controller) => controller.text).join();

  @override
  void dispose() {
    widget.sessionStore.removeListener(_sessionChanged);
    _timer?.cancel();
    _passwordConfirmation.dispose();
    _email.dispose();
    _password.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _openOtpEntry(_AuthMode mode) {
    for (final controller in _otpControllers) {
      controller.clear();
    }
    setState(() => _mode = mode);
    _cooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _otpFocusNodes.first.requestFocus();
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if ((_mode == _AuthMode.verify || _mode == _AuthMode.resetVerify) &&
        _email.text.trim().isEmpty) {
      setState(() => _error = 'Recomece o processo para confirmar seu e-mail.');
      return;
    }
    if (_showsEmail && _email.text.trim().isEmpty) {
      setState(() => _error = 'Informe seu e-mail.');
      return;
    }
    if (_needsPassword && _password.text.length < 12) {
      setState(() => _error = 'A senha precisa ter pelo menos 12 caracteres.');
      return;
    }
    if (_needsCode && _otpCode.length != 6) {
      setState(() => _error = 'Informe os seis dígitos do código.');
      return;
    }
    if ((_mode == _AuthMode.register || _mode == _AuthMode.resetConfirm) &&
        _password.text != _passwordConfirmation.text) {
      setState(() => _error = 'As senhas precisam ser iguais.');
      return;
    }

    try {
      switch (_mode) {
        case _AuthMode.login:
          await widget.sessionStore.login(
            email: _email.text,
            password: _password.text,
          );
        case _AuthMode.register:
          await widget.sessionStore.register(
            email: _email.text,
            password: _password.text,
          );
          if (mounted) {
            _openOtpEntry(_AuthMode.verify);
          }
        case _AuthMode.verify:
          await widget.sessionStore.verifyEmail(
            email: _email.text,
            code: _otpCode,
          );
        case _AuthMode.resetRequest:
          await widget.sessionStore.requestPasswordReset(_email.text);
          if (mounted) {
            _openOtpEntry(_AuthMode.resetVerify);
          }
        case _AuthMode.resetVerify:
          final token = await widget.sessionStore.verifyResetCode(
            _email.text,
            _otpCode,
          );
          if (mounted) {
            setState(() {
              _resetToken = token;
              _mode = _AuthMode.resetConfirm;
              _password.clear();
              _passwordConfirmation.clear();
            });
          }
        case _AuthMode.resetConfirm:
          await widget.sessionStore.completeReset(_resetToken!, _password.text);
          if (mounted) {
            await widget.sessionStore.clearLocalSession();
            if (mounted) {
              setState(() {
                _mode = _AuthMode.login;
                _password.clear();
                _resetToken = null;
                _error = null;
              });
            }
          }
      }
    } on AuthApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível concluir agora. Tente novamente.',
        );
      }
    }
  }

  String get _title => switch (_mode) {
    _AuthMode.login => 'Entre na sua coleção',
    _AuthMode.register => 'Crie sua conta',
    _AuthMode.verify => 'Confira seu e-mail',
    _AuthMode.resetRequest => 'Recupere sua senha',
    _AuthMode.resetVerify => 'Verifique o código',
    _AuthMode.resetConfirm => 'Defina uma nova senha',
  };

  String get _subtitle => switch (_mode) {
    _AuthMode.login => 'e leve suas descobertas com você.',
    _AuthMode.register => 'Cadastre-se para sincronizar seus gatos.',
    _AuthMode.verify =>
      'Enviamos um código de seis dígitos para ${_maskedEmail(_email.text)}.',
    _AuthMode.resetRequest => 'Informe o e-mail cadastrado na sua conta.',
    _AuthMode.resetVerify =>
      'Digite o código que enviamos para ${_maskedEmail(_email.text)}.',
    _AuthMode.resetConfirm => 'Crie uma senha segura com pelo menos 12 dígitos.',
  };

  String get _buttonLabel => switch (_mode) {
    _AuthMode.login => 'Entrar',
    _AuthMode.register => 'Criar conta',
    _AuthMode.verify => 'Confirmar e entrar',
    _AuthMode.resetRequest => 'Enviar código',
    _AuthMode.resetVerify => 'Verificar código',
    _AuthMode.resetConfirm => 'Salvar nova senha',
  };

  String _maskedEmail(String email) {
    final parts = email.trim().split('@');
    if (parts.length != 2 || parts.first.isEmpty) {
      return 'seu e-mail';
    }
    final local = parts.first;
    final visible = local.length == 1 ? local : local.substring(0, 1);
    return '$visible•••@${parts.last}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Folha decorativa superior esquerda (ramo saindo da lateral/topo - Folha_2 com orientação horizontal)
          Positioned(
            top: -20,
            left: -35,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: 0.38, // ~22 graus no sentido horário para alinhar o caule horizontalmente
                child: Image.asset(
                  'assets/images/Folha_2.png',
                  width: 310,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // Folha 3: as duas folhinhas ao lado do gato
          Positioned(
            top: 145,
            right: 42,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/Folha_3.png',
                width: 36,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Folha 4: folhinhas caindo na margem esquerda rente ao botão Entrar
          Positioned(
            top: 415,
            left: -4,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/Folha_4.png',
                width: 44,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Ilustração inferior direita (vaso/tijolos com folhagens - Folha_6)
          Positioned(
            bottom: 0,
            right: -8,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/Folha_6.png',
                width: 250,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Conteúdo central rolável
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: AnimatedBuilder(
                    animation: widget.sessionStore,
                    builder: (context, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Conjunto Gato deitado + Logo Gatálogo
                        Center(
                          child: SizedBox(
                            width: 240,
                            height: 158,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.topCenter,
                              children: [
                                Positioned(
                                  top: 0,
                                  child: Image.asset(
                                    'assets/images/gato_3.png',
                                    width: 172,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Positioned(
                                  top: 92,
                                  child: Image.asset(
                                    'assets/images/Logo.png',
                                    width: 215,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Título e Subtítulo
                        Text(
                          _title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textTitle,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            height: 1.15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMedium,
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Input E-mail
                        if (_showsEmail)
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.inputBg,
                              hintText: 'E-mail',
                              hintStyle: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textLight,
                              ),
                              prefixIcon: const Icon(
                                LucideIcons.mail,
                                size: 18,
                                color: AppColors.textMedium,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                  width: 1.2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                  width: 1.2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.4,
                                ),
                              ),
                            ),
                          ),

                        // Input Senha
                        if (_needsPassword) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            obscureText: !_showPassword,
                            enableSuggestions: false,
                            autocorrect: false,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.inputBg,
                              hintText: _mode == _AuthMode.resetConfirm
                                  ? 'Nova senha (mínimo 12 caracteres)'
                                  : 'Senha',
                              hintStyle: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textLight,
                              ),
                              prefixIcon: const Icon(
                                LucideIcons.lock,
                                size: 18,
                                color: AppColors.textMedium,
                              ),
                              suffixIcon: IconButton(
                                padding: EdgeInsets.zero,
                                tooltip: _showPassword
                                    ? 'Ocultar senha'
                                    : 'Mostrar senha',
                                onPressed: () => setState(
                                  () => _showPassword = !_showPassword,
                                ),
                                icon: Icon(
                                  _showPassword
                                      ? LucideIcons.eyeOff
                                      : LucideIcons.eye,
                                  size: 18,
                                  color: AppColors.textMedium,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                  width: 1.2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                  width: 1.2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Código OTP
                        if (_needsCode) ...[
                          const SizedBox(height: 14),
                          _OtpCodeInput(
                            controllers: _otpControllers,
                            focusNodes: _otpFocusNodes,
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _resendSeconds > 0 ||
                                      widget.sessionStore.isBusy
                                  ? null
                                  : _resend,
                              child: Text(
                                _resendSeconds > 0
                                    ? 'Reenviar em ${_resendSeconds}s'
                                    : 'Reenviar código',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.greenLink,
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Confirmação de senha
                        if (_mode == _AuthMode.register ||
                            _mode == _AuthMode.resetConfirm) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordConfirmation,
                            obscureText: !_showPassword,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.inputBg,
                              hintText: 'Confirmar senha',
                              hintStyle: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textLight,
                              ),
                              prefixIcon: const Icon(
                                LucideIcons.lock,
                                size: 18,
                                color: AppColors.textMedium,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                  width: 1.2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                  width: 1.2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Link "Esqueci minha senha" alinhado à direita
                        if (_mode == _AuthMode.login) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => setState(
                                () => _mode = _AuthMode.resetRequest,
                              ),
                              child: Text(
                                'Esqueci minha senha',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.greenLink,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Mensagem de erro
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE8E8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFC81E1E),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // Botão Entrar (altura 48, cor #DC8BA1, raio 24)
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: widget.sessionStore.isBusy ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: widget.sessionStore.isBusy
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.pets,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _buttonLabel,
                                        style: GoogleFonts.nunito(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        // Divisor "ou" e Botão Continuar com Google
                        if (_mode == _AuthMode.login ||
                            _mode == _AuthMode.register) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(
                                  color: Color(0xFFDDD5CA),
                                  thickness: 0.8,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  'ou',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textTitle,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(
                                  color: Color(0xFFDDD5CA),
                                  thickness: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Botão Continuar com Google (altura 42, raio 21, fundo #FDF6F5)
                          SizedBox(
                            height: 42,
                            child: OutlinedButton(
                              onPressed: widget.sessionStore.isBusy
                                  ? null
                                  : () async {
                                      try {
                                        await widget.sessionStore
                                            .loginWithGoogle();
                                      } on AuthApiException catch (error) {
                                        if (mounted) {
                                          setState(
                                            () => _error = error.message,
                                          );
                                        }
                                      } catch (_) {
                                        if (mounted) {
                                          setState(
                                            () => _error =
                                                'Não foi possível entrar com Google.',
                                          );
                                        }
                                      }
                                    },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppColors.inputBg,
                                side: const BorderSide(
                                  color: AppColors.border,
                                  width: 1.0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(21),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/google_logo.png',
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Continuar com Google',
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textTitle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Link "Criar minha conta"
                        Center(
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _mode = _mode == _AuthMode.login
                                  ? _AuthMode.register
                                  : _AuthMode.login,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                _mode == _AuthMode.login
                                    ? 'Criar minha conta'
                                    : 'Já tenho uma conta. Entrar',
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),

                        if (_mode == _AuthMode.resetRequest ||
                            _mode == _AuthMode.resetConfirm)
                          Center(
                            child: TextButton(
                              onPressed: () =>
                                  setState(() => _mode = _AuthMode.login),
                              child: Text(
                                'Voltar para entrar',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMedium,
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 14),

                        // Card inferior "Explorar sem conta" (altura 62, raio 18, fundo #F0EEE3)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onContinueOffline,
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              height: 62,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.guestCardBg,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.userX,
                                    color: AppColors.guestCardText,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Explorar sem conta',
                                          style: GoogleFonts.nunito(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.guestCardText,
                                          ),
                                        ),
                                        Text(
                                          'Sua coleção fica salva apenas localmente.',
                                          style: GoogleFonts.nunito(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.guestCardSubtext,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    LucideIcons.chevronRight,
                                    color: AppColors.guestCardText,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpCodeInput extends StatelessWidget {
  const _OtpCodeInput({required this.controllers, required this.focusNodes});

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Código de verificação de seis dígitos',
      child: Row(
        children: List.generate(6, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == 5 ? 0 : 6),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFAF8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1.2),
                ),
                child: TextField(
                  controller: controllers[index],
                  focusNode: focusNodes[index],
                  autofocus: index == 0,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                  maxLength: 1,
                  autofillHints: index == 0
                      ? const [AutofillHints.oneTimeCode]
                      : null,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && index < focusNodes.length - 1) {
                      focusNodes[index + 1].requestFocus();
                    } else if (value.isEmpty && index > 0) {
                      focusNodes[index - 1].requestFocus();
                    }
                  },
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}


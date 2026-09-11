import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/analysis_api_service.dart';
import '../services/cat_preflight_service.dart';
import '../services/location_service.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import 'cat_details_page.dart';

class CapturePage extends StatefulWidget {
  const CapturePage({super.key, required this.catStore});

  final CatStore catStore;

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  final ImagePicker _picker = ImagePicker();
  final CatPreflightService _preflight = CatPreflightService();

  bool _isAnalyzing = false;
  bool _isValidating = false;

  File? _foto;
  Future<Position?>? _locationAtCapture;
  DateTime? _capturedAt;

  @override
  void initState() {
    super.initState();
    _preflight.warmUp();
  }

  Future<void> _tirarFoto() async {
    try {
      await _escolherFoto(ImageSource.camera);
    } catch (_) {
      if (mounted) {
        setState(() => _isValidating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível abrir a câmera. Confira a permissão do aplicativo e tente novamente.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _escolherFoto(ImageSource source) async {
    final XFile? imagem = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (imagem == null || !mounted) {
      return;
    }

    _capturedAt = DateTime.now();
    _locationAtCapture = LocationService.getCurrentLocation()
        .timeout(const Duration(seconds: 20), onTimeout: () => null)
        .catchError((Object _) => null);

    setState(() {
      _foto = File(imagem.path);
      _isValidating = true;
    });

    final result = await _preflight
        .validate(imagem.path)
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () => const CapturePreflightResult.accepted(),
        );

    if (!mounted) {
      return;
    }

    if (!result.accepted) {
      setState(() {
        _foto = null;
        _isValidating = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message!)));
      return;
    }

    setState(() {
      _isValidating = false;
    });
  }

  void _cancelarFoto() {
    if (_isAnalyzing || _isValidating) {
      return;
    }

    setState(() {
      _foto = null;
    });
  }

  Future<void> _confirmarFoto() async {
    if (_foto == null || _isAnalyzing || _isValidating) {
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final saved = await widget.catStore.addFromTempPhoto(
        _foto!.path,
        capturedAt: _capturedAt,
      );

      unawaited(_attachLocationInBackground(saved.cat.id, _locationAtCapture));

      if (!mounted) {
        return;
      }

      setState(() {
        _foto = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved.awaitingConnection
                ? 'Foto salva. Ela será enviada quando houver conexão.'
                : 'Descoberta salva na sua coleção!',
          ),
        ),
      );

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CatDetailsPage(cat: saved.cat, catStore: widget.catStore),
          ),
        );
      }
    } on AnalysisRejectedException catch (error) {
      if (!mounted) {
        return;
      }

      final message = _messageForRejection(error.code);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on AnalysisConnectionException {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível conectar ao serviço de análise.'),
        ),
      );
    } on AnalysisApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error, stackTrace) {
      debugPrint('ERRO AO GATALOGAR: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao salvar gato: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _attachLocationInBackground(
    String catId,
    Future<Position?>? capturedLocation,
  ) async {
    try {
      final position = await capturedLocation;
      if (position == null) {
        return;
      }
      final locationName = await LocationService.getLocationName(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 5), onTimeout: () => null);
      await widget.catStore.updateCatLocation(
        catId,
        latitude: position.latitude,
        longitude: position.longitude,
        locationName: locationName,
      );
    } catch (error) {
      debugPrint('Localização não pôde ser anexada: $error');
    }
  }

  String _messageForRejection(String code) {
    switch (code) {
      case 'NOT_A_CAT':
        return 'Não encontramos um gato nessa foto.';
      case 'MULTIPLE_CATS':
        return 'Fotografe apenas um gato por vez.';
      case 'LOW_QUALITY':
        return 'A foto não possui qualidade suficiente para analisar a pelagem.';
      case 'CAT_NOT_IDENTIFIABLE':
        return 'Não conseguimos identificar o gato com clareza.';
      case 'SEXUAL_CONTENT':
      case 'GRAPHIC_CONTENT':
      case 'UNSAFE_CONTENT':
        return 'Esta imagem não pode ser utilizada no Gatálogo.';
      case 'INVALID_IMAGE':
        return 'O arquivo selecionado não é uma imagem válida.';
      default:
        return 'Não foi possível utilizar esta imagem.';
    }
  }

  @override
  void dispose() {
    _preflight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _foto == null ? _buildCaptura() : _buildPreview(),
      ),
    );
  }

  Widget _buildCaptura() {
    return Stack(
      children: [
        // Ramo de folhas à esquerda atrás do título
        Positioned(
          top: 60,
          left: -35,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: 0.25,
              child: Image.asset(
                'assets/images/Folha_1.png',
                width: 170,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        // Ilustração inferior direita (vaso com plantas e tijolos)
        Positioned(
          bottom: -15,
          right: -10,
          child: IgnorePointer(
            child: Image.asset(
              'assets/images/Folha_6.png',
              width: 175,
              fit: BoxFit.contain,
            ),
          ),
        ),

        // Conteúdo da tela
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Topo: Logo e Avatar de perfil
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/Logo.png',
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE8D6DE),
                        width: 1.4,
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.user,
                      size: 20,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Hero: Título + Ilustração do gatinho com a câmera rosa
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Encontrou\num gato?',
                          style: GoogleFonts.nunito(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textTitle,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Registre uma nova\ndescoberta para\nsua coleção',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTitle,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Gatinho com a câmera rosa sobre elipse suave
                  SizedBox(
                    width: 160,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          bottom: 0,
                          child: Container(
                            width: 140,
                            height: 35,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCEBE8),
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                        ),
                        Image.asset(
                          'assets/images/gato_1.png',
                          height: 135,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Card: Como Funciona
              Container(
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Folhinha caindo no topo direito do card (Folha_3)
                    Positioned(
                      top: -10,
                      right: 14,
                      child: IgnorePointer(
                        child: Image.asset(
                          'assets/images/Folha_3.png',
                          width: 44,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Como Funciona',
                            style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Passo 1: Fotografe
                              Expanded(
                                child: _StepItem(
                                  circleColor: const Color(0xFFFCEBE8),
                                  icon: LucideIcons.camera,
                                  title: 'Fotografe',
                                  description: 'Tire uma\nfoto nítida\ndo gato.',
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(top: 18),
                                child: Icon(
                                  LucideIcons.arrowRight,
                                  size: 16,
                                  color: AppColors.textDark,
                                ),
                              ),
                              // Passo 2: Analise
                              Expanded(
                                child: _StepItem(
                                  circleColor: const Color(0xFFE2EAD9),
                                  icon: LucideIcons.search,
                                  title: 'Analise',
                                  description: 'Nosso\nsistema\nidentifica a\npelagem.',
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(top: 18),
                                child: Icon(
                                  LucideIcons.arrowRight,
                                  size: 16,
                                  color: AppColors.textDark,
                                ),
                              ),
                              // Passo 3: Colecione
                              Expanded(
                                child: _StepItem(
                                  circleColor: const Color(0xFFFCEBE8),
                                  icon: LucideIcons.bookHeart,
                                  title: 'Colecione',
                                  description: 'Adicione ao\nseu\nGatálogo!',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Botão Principal: "Abrir câmera" (altura 50, raio 25, rosa #DC8BA1)
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isAnalyzing || _isValidating ? null : _tirarFoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.camera,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Abrir câmera',
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

              const SizedBox(height: 10),

              // Botão secundário de escolher da galeria
              Center(
                child: TextButton.icon(
                  onPressed: _isAnalyzing || _isValidating
                      ? null
                      : () => _escolherFoto(ImageSource.gallery),
                  icon: const Icon(LucideIcons.image, size: 16, color: AppColors.textMedium),
                  label: Text(
                    'Ou escolha da galeria',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMedium,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Card de Dica / Aviso (fundo #FCEDED, raio 18)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoftBg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.pawPrint,
                      size: 28,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Uma foto nítida ajuda a identificar melhor o gato.',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Evite fotos escuras ou muito distantes!',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.file(
                _foto!,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed:
                        _isAnalyzing || _isValidating ? null : _cancelarFoto,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppColors.border,
                        width: 1.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: Text(
                      'Tirar outra',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isAnalyzing || _isValidating
                        ? null
                        : _confirmarFoto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: _isAnalyzing || _isValidating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Usar foto',
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
          if (_isValidating) ...[
            const SizedBox(height: 12),
            Text(
              'Conferindo enquadramento e qualidade…',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.circleColor,
    required this.icon,
    required this.title,
    required this.description,
  });

  final Color circleColor;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 24, color: AppColors.textDark),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textMedium,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

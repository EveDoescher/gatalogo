import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/habitat_service.dart';
import '../game/habitat_cat_animations.dart';
import '../game/habitat_game.dart';
import '../game/habitat_cat_coat.dart';
import '../game/quintal_game_motion.dart';
import '../game/quintal_play_motion.dart';
import '../game/quintal_play_result.dart';
import '../widgets/quintal_play_arena.dart';
import '../services/product_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/quintal_production_widgets.dart';
import '../widgets/quintal_clock_badge.dart';
import '../widgets/quintal_activity_result.dart';
import '../widgets/quintal_fishing_arena.dart';
import '../widgets/quintal_hold_control.dart';

class QuintalGamePage extends StatefulWidget {
  static Future<bool> open(
    BuildContext context, {
    required HabitatService habitat,
    String? catId,
    String? catName,
    HabitatGame? scene,
    Offset sceneOrigin = Offset.zero,
  }) async {
    if (scene?.activityInProgress == true) return false;
    scene?.beginActivity(catId);
    try {
      return await showGeneralDialog<bool>(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.transparent,
            transitionDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160),
            pageBuilder: (context, animation, secondaryAnimation) =>
                QuintalGamePage(
                  habitat: habitat,
                  catId: catId,
                  catName: catName,
                  inWorld: true,
                  scene: scene,
                  sceneOrigin: sceneOrigin,
                ),
            transitionBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) => FadeTransition(opacity: animation, child: child),
          ) ??
          false;
    } finally {
      scene?.endActivity();
    }
  }

  const QuintalGamePage({
    super.key,
    required this.habitat,
    this.catId,
    this.catName,
    this.inWorld = false,
    this.clock,
    this.scene,
    this.sceneOrigin = Offset.zero,
  });
  final HabitatService habitat;
  @visibleForTesting
  final Stopwatch? clock;
  final String? catId, catName;
  final bool inWorld;
  final HabitatGame? scene;
  final Offset sceneOrigin;
  @override
  State<QuintalGamePage> createState() => _QuintalGamePageState();
}

class _QuintalGamePageState extends State<QuintalGamePage>
    with WidgetsBindingObserver {
  Timer? _timer;
  final _catGeometry = HabitatCatAnimations();
  late final HabitatCatAnimations _cat;
  final _playMotion = QuintalPlayMotion();
  Map<String, dynamic>? _session;
  late final _clock = widget.clock ?? Stopwatch();
  final _trace = <Map<String, dynamic>>[];
  double _position = .5, _score = 0;
  double _lastFrameTime = 0;
  bool _held = false, _finishing = false;
  bool _usingSlider = false;
  String? _error;
  bool _restartRequired = false;
  bool _interruptedDuringStart = false;
  bool _starting = false;
  Map<String, dynamic>? _result;
  bool get _fishing => widget.catId == null;
  double get _wait =>
      _fishing ? (_session?['bite_seconds'] as num?)?.toDouble() ?? 0 : 0;
  double get _time => (_clock.elapsedMilliseconds / 1000 - _wait).clamp(0, 30);
  bool get _waiting =>
      _session != null && _clock.elapsedMilliseconds / 1000 < _wait;
  double get _fish =>
      (.5 +
              .28 *
                  math.sin(
                    _time * ((_session?['speed'] as num?)?.toDouble() ?? .3) +
                        ((_session?['phase'] as num?)?.toDouble() ?? 0),
                  ) +
              .1 * math.sin(_time * .7))
          .clamp(0, 1);
  double get _zone => (_session?['zone'] as num?)?.toDouble() ?? .3;
  @override
  void initState() {
    super.initState();
    final cat = widget.habitat.cats
        .where((c) => c.id == widget.catId)
        .firstOrNull;
    _cat = HabitatCatAnimations.coat(
      HabitatCatCoat.resolve(
        primaryColor: cat?.primaryColor,
        coatType: cat?.coatType,
        colors: cat?.coatColors ?? const [],
      ),
      _catGeometry,
    );
    WidgetsBinding.instance.addObserver(this);
    // Starting a session notifies the world behind this dialog. Wait until
    // both routes have finished building before publishing that state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  Future<void> _start() async {
    _starting = true;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _interruptedDuringStart =
        lifecycle != null && lifecycle != AppLifecycleState.resumed;
    try {
      if (!_fishing) {
        await _cat.initialize();
        await Future.wait([
          _cat.preload(HabitatCatClip.walk),
          _cat.preload(HabitatCatClip.idle),
          _cat.preload(HabitatCatClip.happy),
        ]);
      }
      if (!mounted) return;
      if (_interruptedDuringStart) {
        _pauseSession();
        return;
      }
      _session = await widget.habitat.produce(
        _fishing ? 'start_fish' : 'start_play',
        widget.catId ?? 'pier',
      );
      if (!mounted) return;
      if (_interruptedDuringStart) {
        _pauseSession();
        return;
      }
      _lastFrameTime = 0;
      _clock.start();
      _timer = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
      setState(() {});
    } on ProductApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      _starting = false;
    }
  }

  void _tick() {
    if (!mounted || _finishing || _result != null) return;
    if (_clock.elapsedMilliseconds / 1000 < _wait) {
      setState(() {});
      return;
    }
    final t = _time.clamp(0.0, 20.0);
    final elapsed = (t - _lastFrameTime).clamp(0.0, 20.0);
    _lastFrameTime = t;
    if (_fishing && !_usingSlider) {
      _position = QuintalGameMotion.fishing(_position, _held, elapsed);
    }
    if (!_fishing) {
      _playMotion.advance(_position, elapsed);
      widget.scene?.updatePlayActivity(_playMotion, _position, t);
    }
    if (_trace.isEmpty || t - (_trace.last['t'] as double) >= 1) {
      _trace.add({'t': t, 'position': _position});
    }
    if (!_fishing || (_position - _fish).abs() <= _zone / 2) _score += elapsed;
    setState(() {});
    if (t >= 20) unawaited(_finish());
  }

  Future<void> _finish() async {
    _timer?.cancel();
    _playMotion.settle();
    widget.scene?.updatePlayActivity(_playMotion, _position, _time);
    if (_clock.isRunning) {
      _clock.stop();
      if (_trace.isEmpty || _time > (_trace.last['t'] as num)) {
        _trace.add({'t': _time, 'position': _position});
      }
    }
    setState(() => _finishing = true);
    try {
      final result = await widget.habitat.produce(
        _fishing ? 'finish_fish' : 'finish_play',
        _session!['session_id'].toString(),
        {'trace': _trace},
      );
      if (mounted) setState(() => _result = result);
    } on ProductApiException catch (error) {
      // An invalid trace cannot be repaired by replaying the same payload.
      // Network/5xx failures remain uncertain and retry the original session.
      _restartRequired = error.statusCode == 409 || error.statusCode == 422;
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _clock.stop();
    _cat.dispose();
    _catGeometry.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _starting) {
      _interruptedDuringStart = true;
    }
    if (state == AppLifecycleState.resumed ||
        _result != null ||
        _finishing ||
        _session == null) {
      return;
    }
    _pauseSession();
  }

  void _pauseSession() {
    _timer?.cancel();
    _playMotion.settle();
    widget.scene?.updatePlayActivity(_playMotion, _position, _time);
    _clock.stop();
    setState(() {
      _held = false;
      _restartRequired = true;
      _error = 'A atividade foi pausada. Vamos tentar de novo?';
    });
  }

  String get _playCaption => switch (_playMotion.phase) {
    QuintalPlayPhase.watching => 'Mova a varinha para chamar a atenção',
    QuintalPlayPhase.chasing => 'De olho na varinha!',
    QuintalPlayPhase.reaching => 'Quase pegou!',
    QuintalPlayPhase.resting => 'Uma pausa para respirar',
  };

  Widget _worldPlayArena() {
    void point(Offset global) {
      if (_finishing) return;
      setState(
        () => _position = widget.scene!.playControlAt(
          global - widget.sceneOrigin,
        ),
      );
    }

    return Column(
      children: [
        _paper(
          Text(
            _playCaption,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.greenLink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            key: const ValueKey('world-play-control'),
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => point(details.globalPosition),
            onPanUpdate: (details) => point(details.globalPosition),
            onTapDown: (details) => point(details.globalPosition),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  Widget _paper(
    Widget child, {
    EdgeInsets padding = const EdgeInsets.all(10),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: widget.inWorld ? Colors.transparent : AppColors.surface,
    appBar: AppBar(
      backgroundColor: widget.inWorld ? Colors.transparent : AppColors.surface,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: MediaQuery.textScalerOf(context).scale(18) > 24 ? 72 : 56,
      leading: IconButton.filled(
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textTitle,
        ),
        tooltip: 'Voltar ao Quintal',
        onPressed: () => Navigator.pop(context, _result?['success'] == true),
        icon: const Icon(Icons.close),
      ),
      title: _paper(
        Text(
          _fishing
              ? 'Pescar no píer'
              : 'Brincar com ${widget.catName ?? 'seu gato'}',
          maxLines: 2,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_session != null && _result == null && _error == null) ...[
              _paper(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _fishing
                          ? (_waiting
                                ? 'A linha está na água'
                                : _time < 1.5
                                ? 'Fisgou! Acompanhe o peixe'
                                : 'Mantenha a faixa junto do peixe')
                          : 'Mova a varinha para seu gato acompanhar',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fishing
                          ? (_waiting
                                ? 'Espere o peixe morder.'
                                : 'Segure para subir, solte para descer. Ou use o controle abaixo.')
                          : 'Arraste a varinha ou use o controle abaixo.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_session?['practice'] == true && _fishing)
                      const Text(
                        'Prática · sem adicionar peixes ao inventário.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _paper(
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.textTitle),
                        ),
                      ),
                      TextButton(
                        onPressed: _finishing
                            ? null
                            : () {
                                setState(() => _error = null);
                                if (_session == null || _restartRequired) {
                                  _clock.reset();
                                  _trace.clear();
                                  _position = .5;
                                  _usingSlider = false;
                                  _held = false;
                                  _playMotion.reset();
                                  _score = 0;
                                  _session = null;
                                  _restartRequired = false;
                                  unawaited(_start());
                                } else {
                                  unawaited(_finish());
                                }
                              },
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_result != null)
              Expanded(
                child: QuintalActivityResult(
                  success: _result!['success'] == true,
                  title: _result!['success'] != true
                      ? (_fishing
                            ? 'O peixe escapou'
                            : 'Vamos brincar de novo?')
                      : _fishing
                      ? (_result!['practice'] == true
                            ? 'Boa captura de treino!'
                            : 'Boa pescaria!')
                      : 'Uma boa brincadeira juntos!',
                  description: _result!['success'] != true
                      ? (_fishing
                            ? 'Na próxima, acompanhe o peixe com a faixa. Nenhum peixe foi adicionado ao inventário.'
                            : 'Mova a varinha para seu gato acompanhar durante a brincadeira.')
                      : _fishing
                      ? ((_result!['quantity'] as num? ?? 0) > 0
                            ? '${_result!['quantity']} peixe(s) no inventário!'
                            : _result!['practice'] == true
                            ? 'Treino concluído, sem adicionar peixes ao inventário.'
                            : 'O limite de capturas premiadas foi atingido. Nenhum peixe foi adicionado.')
                      : quintalPlayResultDescription(_result!),
                  artwork: _fishing
                      ? QuintalArtwork(
                          _result!['success'] == true
                              ? 'fish'
                              : 'action_fish_rod',
                          size: 160,
                        )
                      : CustomPaint(
                          painter: _PlayingCatPainter(
                            _cat.frame(
                              _result!['success'] == true
                                  ? HabitatCatClip.happy
                                  : HabitatCatClip.idle,
                              0,
                              0,
                            ),
                          ),
                        ),
                  onClose: () =>
                      Navigator.pop(context, _result?['success'] == true),
                ),
              )
            else if (_session == null)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else ...[
              if (_waiting)
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: QuintalArtwork('action_fish_rod', size: 180),
                      ),
                      SizedBox(height: 16),
                      QuintalClockBadge(size: 42),
                      SizedBox(height: 12),
                      Text('Aguardando uma mordida…'),
                    ],
                  ),
                )
              else if (_fishing)
                Expanded(
                  child: QuintalFishingArena(
                    fish: _fish,
                    position: _position,
                    zone: _zone,
                  ),
                )
              else if (widget.scene?.hasWorldPlay == true)
                Expanded(child: _worldPlayArena())
              else
                Expanded(
                  child: QuintalPlayArena(
                    showGround: !widget.inWorld,
                    position: _playMotion.position,
                    target: _position,
                    lift: MediaQuery.disableAnimationsOf(context)
                        ? 0
                        : _playMotion.lift,
                    caption: _playCaption,
                    onTarget: _finishing
                        ? null
                        : (value) => setState(() => _position = value),
                    cat: CustomPaint(
                      painter: _PlayingCatPainter(
                        _cat.frame(
                          switch (_playMotion.phase) {
                            QuintalPlayPhase.chasing => HabitatCatClip.walk,
                            QuintalPlayPhase.reaching => HabitatCatClip.happy,
                            _ => HabitatCatClip.idle,
                          },
                          MediaQuery.disableAnimationsOf(context) ? 0 : _time,
                          _playMotion.direction,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (!_waiting)
                _paper(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Slider(
                        activeColor: AppColors.greenLink,
                        inactiveColor: const Color(0xFFE4D9BB),
                        value: _position,
                        onChanged: _finishing || _error != null
                            ? null
                            : (value) => setState(() {
                                _position = value;
                                _usingSlider = true;
                              }),
                        semanticFormatterCallback: (v) =>
                            'Posição ${(v * 100).round()}',
                      ),
                      if (_fishing)
                        QuintalHoldControl(
                          held: _held,
                          onChanged: _finishing
                              ? null
                              : (held) => setState(() {
                                  _held = held;
                                  _usingSlider = false;
                                }),
                        ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_time / 20).clamp(0, 1),
                        minHeight: 8,
                      ),
                      Text(
                        _finishing
                            ? 'Conferindo a atividade…'
                            : '${(20 - _time).ceil().clamp(0, 20)} s · ${_fishing ? '${(_score / math.max(1, _time) * 100).clamp(0, 100).round()}% acompanhando' : 'Acompanhe com a varinha'}',
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _PlayingCatPainter extends CustomPainter {
  const _PlayingCatPainter(this.frame);
  final HabitatCatFrame? frame;
  @override
  void paint(Canvas canvas, Size size) {
    final f = frame;
    if (f == null) return;
    final scale = size.height / f.visible.height * .85;
    final ground = Offset(size.width / 2, size.height - 8);
    f.paint(canvas, ground, scale, groundShadow: true);
    f.paint(canvas, ground, scale);
  }

  @override
  bool shouldRepaint(_PlayingCatPainter oldDelegate) =>
      oldDelegate.frame != frame;
}

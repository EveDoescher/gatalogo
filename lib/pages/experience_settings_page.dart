import '../widgets/botanical_scene.dart';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../services/experience_service.dart';
import '../services/product_api_service.dart';
import '../stores/session_store.dart';
import 'public_profile_page.dart';

class ExperienceSettingsPage extends StatefulWidget {
  const ExperienceSettingsPage({super.key, required this.session});
  final SessionStore session;
  @override
  State<ExperienceSettingsPage> createState() => _ExperienceSettingsPageState();
}

class _ExperienceSettingsPageState extends State<ExperienceSettingsPage> {
  final _experience = ExperienceService.instance;
  Map<String, dynamic> _preferences = {};
  String? _username, _error;
  bool _loading = true, _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _experience.initialize();
      if (widget.session.isSignedIn) {
        final account = await ProductApiService(widget.session)
            .get('/app/account');
        if (!mounted) return;
        _preferences = Map<String, dynamic>.from(
          account['preferences'] as Map? ?? {},
        );
        _username = account['username'] as String?;
      }
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _audience(String section, String value) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ProductApiService(widget.session)
          .put('/app/preferences', {'${section}_audience': value});
      if (mounted) setState(() => _preferences['${section}_audience'] = value);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _audio(String key, bool value) async {
    try {
      await _experience.setPreference(key, value);
      if (widget.session.isSignedIn) {
        await ProductApiService(widget.session).post(
          '/app/progress/experience',
          {'event_id': const Uuid().v4(), 'name': 'audio_changed'},
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível salvar esta preferência. Tente novamente.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => BotanicalScaffold(
    level: BotanicalLevel.tertiary,
    appBar: AppBar(title: const Text('Experiência e privacidade')),
    body: AnimatedBuilder(
      animation: _experience,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const IllustratedPaperHeading(
            title: 'No seu ritmo',
            description: 'Som e movimento são opcionais. O app respeita o silêncio do aparelho.',
            art: 'icons/icon_yarn_ball_pink',
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Música'),
            subtitle: const Text(
              'Somente em Início, Coleção, Resultado e Habitat',
            ),
            value: _experience.music,
            onChanged: (v) => _audio('music', v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Efeitos de descoberta'),
            value: _experience.effects,
            onChanged: (v) => _audio('effects', v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vibração'),
            value: _experience.vibration,
            onChanged: (v) => _audio('vibration', v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Movimento extra'),
            subtitle: const Text(
              'A redução de movimento do aparelho tem prioridade',
            ),
            value: _experience.motion,
            onChanged: (v) => _audio('motion', v),
          ),
          const Divider(height: 40),
          const IllustratedSectionTitle(
            title: 'Quem vê meu Perfil',
            art: 'ui/ui_avatar_frame_floral_round',
          ),
          const SizedBox(height: 8),
          const Text(
            'Publicações que você já compartilhou mantêm a audiência escolhida. Localização precisa não aparece na vitrine.',
          ),
          if (_loading) const LinearProgressIndicator(),
          if (!widget.session.isSignedIn)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Entre em uma conta para controlar sua vitrine. Seus registros locais continuam privados.',
              ),
            ),
          if (widget.session.isSignedIn && !_loading) ...[
            for (final section in const {
              'gallery': 'Galeria',
              'medals': 'Medalhas',
              'habitat': 'Prévia do Habitat',
            }.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: DropdownButtonFormField<String>(
                  initialValue:
                      _preferences['${section.key}_audience'] as String? ??
                      'friends',
                  decoration: InputDecoration(labelText: section.value),
                  items: const [
                    DropdownMenuItem(value: 'private', child: Text('Só eu')),
                    DropdownMenuItem(value: 'friends', child: Text('Amigos')),
                    DropdownMenuItem(
                      value: 'public',
                      child: Text('Comunidade'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) {
                          if (v != null) _audience(section.key, v);
                        },
                ),
              ),
            if (_username != null)
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PublicProfilePage(
                      sessionStore: widget.session,
                      username: _username!,
                      viewAsFriend: true,
                    ),
                  ),
                ),
                child: const Text('Como amigos me veem'),
              ),
          ],
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
  );
}

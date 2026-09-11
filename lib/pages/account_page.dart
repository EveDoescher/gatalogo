import 'package:flutter/material.dart';

import '../stores/session_store.dart';
import '../stores/cat_store.dart';
import '../services/product_api_service.dart';
import '../widgets/app_widgets.dart';
import 'auth_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.sessionStore, this.catStore});
  final SessionStore sessionStore;
  final CatStore? catStore;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Map<String, dynamic>? _account;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.sessionStore.isSignedIn) return;
    try {
      final data = await ProductApiService(widget.sessionStore)
          .get('/app/account');
      if (mounted) {
        setState(() {
          _account = data;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _auth({bool recovery = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AuthPage(
          sessionStore: widget.sessionStore,
          startWithRecovery: recovery,
          initialEmail: widget.sessionStore.session?.email,
          onContinueOffline: () => Navigator.pop(context),
        ),
      ),
    );
    if (mounted) {
      setState(() {});
      _load();
    }
  }

  Future<void> _preference(String key, bool value) async {
    setState(() => _busy = true);
    try {
      final preferences = Map<String, dynamic>.from(
        _account!['preferences'] as Map,
      )..[key] = value;
      await ProductApiService(widget.sessionStore)
          .request('PUT', '/app/preferences', preferences);
      if (mounted) setState(() => _account!['preferences'] = preferences);
    } catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Conta e configurações')),
    body: AnimatedBuilder(
      animation: widget.sessionStore,
      builder: (context, _) {
        final session = widget.sessionStore.session;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: Text(session?.email ?? 'Usando neste aparelho'),
              subtitle: Text(
                _account?['username'] == null
                    ? 'Sua coleção é privada'
                    : '@${_account!['username']}',
              ),
            ),
            if (session == null) ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Entre ou crie uma conta para vincular seus registros locais e receber possíveis avistamentos.',
                ),
              ),
              FilledButton(
                onPressed: _auth,
                child: const Text('Entrar ou criar conta'),
              ),
            ] else ...[
              if (_error != null)
                ListTile(
                  title: Text(_error!),
                  trailing: IconButton(
                    tooltip: 'Tentar novamente',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Minha coleção'),
                subtitle: Text(
                  widget.catStore == null
                      ? 'Fotos e registros guardados na sua conta.'
                      : '${widget.catStore!.cats.where((cat) => cat.syncState != 'synced').length} registro(s) aguardando envio',
                ),
                trailing: IconButton(
                  tooltip: 'Enviar registros pendentes',
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          await widget.catStore?.syncCatalog();
                          if (mounted) setState(() => _busy = false);
                        },
                  icon: const Icon(Icons.refresh),
                ),
              ),
              const ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Fotos e localização privadas'),
                subtitle: Text(
                  'Seu álbum não aparece no feed. Só conquistas que você decidir compartilhar ficam visíveis aos amigos.',
                ),
              ),
              if (_account != null) ...[
                SwitchListTile(
                  title: const Text('Avisos de possíveis avistamentos'),
                  subtitle: const Text(
                    'Preferência para notificações no aparelho',
                  ),
                  value:
                      (_account!['preferences']
                          as Map)['sighting_notifications'] !=
                      false,
                  onChanged: _busy
                      ? null
                      : (value) => _preference('sighting_notifications', value),
                ),
                SwitchListTile(
                  title: const Text('Avisos de amigos e mensagens'),
                  subtitle: const Text(
                    'A caixa de entrada mantém seu histórico',
                  ),
                  value:
                      (_account!['preferences']
                          as Map)['social_notifications'] !=
                      false,
                  onChanged: _busy
                      ? null
                      : (value) => _preference('social_notifications', value),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.password),
                title: const Text('Alterar senha'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _auth(recovery: true),
              ),
              const Divider(),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        await widget.sessionStore.logout();
                        if (context.mounted) Navigator.pop(context);
                      },
                icon: const Icon(Icons.logout),
                label: const Text('Sair da conta'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        if (!await confirmAction(
                          context,
                          'Desativar conta?',
                          'Seus dados serão guardados. Você poderá reativar a conta confirmando novamente seu e-mail ou entrando com Google.',
                          'Desativar',
                        )) {
                          return;
                        }
                        setState(() => _busy = true);
                        try {
                          await widget.sessionStore.deactivate();
                          if (context.mounted) Navigator.pop(context);
                        } catch (error) {
                          if (context.mounted) showMessage(context, error);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: const Text('Desativar conta'),
              ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Sobre o Gatálogo'),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Gatálogo',
                applicationLegalese: 'Modelo “Cat Low Poly” por lilyjoyhanna, Sketchfab, licença CC-BY 4.0.',
              ),
            ),
          ],
        );
      },
    ),
  );
}

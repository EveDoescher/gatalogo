import 'package:flutter/material.dart';

import '../services/social_api_service.dart';
import '../services/product_api_service.dart';
import '../stores/session_store.dart';
import '../widgets/app_widgets.dart';
import 'conversation_page.dart';
import 'account_page.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({super.key, required this.sessionStore});
  final SessionStore sessionStore;
  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  late final SocialApiService _api;
  late final ProductApiService _product;
  final _username = TextEditingController(), _invite = TextEditingController();
  bool _loading = false, _busy = false;
  String? _error, _chosenName;
  List<Map<String, dynamic>> _friends = [], _invites = [], _feed = [];
  @override
  void initState() {
    super.initState();
    _api = SocialApiService(widget.sessionStore);
    _product = ProductApiService(widget.sessionStore);
    _load();
  }

  @override
  void dispose() {
    _username.dispose();
    _invite.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!widget.sessionStore.isSignedIn) return;
    setState(() => _loading = true);
    try {
      final account = await _product.get('/app/account');
      final data = await Future.wait([
        _api.friends(),
        _api.invites(),
        _api.feed(),
      ]);
      if (mounted) {
        setState(() {
          _chosenName = account['username'] as String?;
          _friends = data[0];
          _invites = data[1];
          _feed = data[2];
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.sessionStore.isSignedIn) {
      return EmptyContent(
        'Encontre seus amigos',
        'Entre na sua conta para enviar convites e conversar.',
        action: FilledButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AccountPage(sessionStore: widget.sessionStore),
              ),
            );
            if (mounted) {
              setState(() {});
              _load();
            }
          },
          child: const Text('Entrar na conta'),
        ),
      );
    }
    final received = _invites.where(
      (item) =>
          item['status'] == 'pending' &&
          (item['recipient'] as Map)['id'] ==
              widget.sessionStore.session!.userId,
    );
    final sent = _invites.where(
      (item) =>
          item['status'] == 'pending' &&
          (item['sender'] as Map)['id'] == widget.sessionStore.session!.userId,
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Text(
            'Encontre pessoas pelo @nome de usuário. Seu e-mail fica privado.',
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            ListTile(
              title: Text(_error!),
              trailing: IconButton(
                tooltip: 'Tentar novamente',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ),
          if (_chosenName == null) ...[
            TextField(
              controller: _username,
              autocorrect: false,
              maxLength: 32,
              decoration: const InputDecoration(
                labelText: 'Escolha seu nome de usuário',
                helperText: '3 a 32 letras minúsculas, números ou _. Não poderá ser alterado.',
              ),
            ),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => _api.chooseUsername(
                        _username.text.trim().toLowerCase(),
                      ),
                    ),
              child: const Text('Salvar nome de usuário'),
            ),
          ] else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text('@$_chosenName'),
            ),
          TextField(
            controller: _invite,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Adicionar por @nome de usuário',
            ),
          ),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await _api.invite(
                      _invite.text.trim().replaceFirst('@', '').toLowerCase(),
                    );
                    _invite.clear();
                  }),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Enviar convite'),
          ),
          if (received.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Convites recebidos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ...received.map(
              (item) => ListTile(
                title: Text('@${(item['sender'] as Map)['username']}'),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Recusar convite',
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => _api.decideInvite(
                                item['id'] as String,
                                false,
                              ),
                            ),
                      icon: const Icon(Icons.close),
                    ),
                    IconButton(
                      tooltip: 'Aceitar convite',
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () =>
                                  _api.decideInvite(item['id'] as String, true),
                            ),
                      icon: const Icon(Icons.check),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (sent.isNotEmpty) ...[
            Text(
              'Convites enviados',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ...sent.map(
              (item) => ListTile(
                title: Text('@${(item['recipient'] as Map)['username']}'),
                subtitle: const Text('Aguardando resposta'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('Seus amigos', style: Theme.of(context).textTheme.titleLarge),
          if (!_loading && _friends.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Envie um convite para começar uma amizade.'),
            ),
          ..._friends.map(
            (friend) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text('@${friend['username']}'),
              onTap: _busy
                  ? null
                  : () => _run(() async {
                      final conversation = await _product.post(
                        '/app/friends/${friend['id']}/conversation',
                      );
                      if (context.mounted) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConversationPage(
                              sessionStore: widget.sessionStore,
                              conversationId: conversation['id'] as String,
                            ),
                          ),
                        );
                      }
                    }),
              trailing: IconButton(
                tooltip: 'Remover amizade',
                icon: const Icon(Icons.person_remove_outlined),
                onPressed: _busy
                    ? null
                    : () async {
                        if (await confirmAction(
                          context,
                          'Remover amizade?',
                          'Vocês deixarão de conversar e de ver novas conquistas um do outro.',
                          'Remover',
                        )) {
                          await _run(
                            () => _api.removeFriend(friend['id'] as String),
                          );
                        }
                      },
              ),
            ),
          ),
          const Divider(height: 36),
          Text(
            'Conquistas dos amigos',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (!_loading && _feed.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('As conquistas compartilhadas aparecerão aqui.'),
            ),
          ..._feed.map(
            (item) => ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: Text('@${item['username']}'),
              subtitle: Text(
                (item['payload'] as Map?)?['title']?.toString() ??
                    'Compartilhou uma conquista',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

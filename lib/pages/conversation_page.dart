import 'dart:async';

import 'package:flutter/material.dart';

import '../services/social_api_service.dart';
import '../services/product_api_service.dart';
import '../stores/session_store.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({
    super.key,
    required this.sessionStore,
    required this.conversationId,
  });
  final SessionStore sessionStore;
  final String conversationId;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  late final SocialApiService _api;
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _messages = const [];
  bool _loading = true;
  bool _sending = false, _fetching = false;
  String? _error;
  String? _username;
  bool _sightingContext = false;
  Timer? _timer;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _api = SocialApiService(widget.sessionStore);
    _load();
    _wsSub = widget.sessionStore.webSocket.onMessage.listen((data) {
      if (data['conversation_id'] == widget.conversationId) {
        _load();
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final metadata = await ProductApiService(widget.sessionStore)
          .get('/app/conversations/${widget.conversationId}');
      final messages = await _api.messages(widget.conversationId);
      if (mounted) {
        setState(() {
          _username = metadata['username'] as String?;
          _sightingContext = metadata['sighting_context'] == true;
        });
      }
      if (mounted) {
        setState(() {
          _messages = messages;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _api.sendMessage(widget.conversationId, body);
      _controller.clear();
      await _load();
    } on SocialApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_username == null ? 'Conversa' : '@$_username'),
      actions: [
        IconButton(
          tooltip: 'Atualizar mensagens',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        if (_sightingContext)
          const ListTile(
            leading: Icon(Icons.pets_outlined),
            title: Text('Conversa sobre um avistamento'),
            subtitle: Text('Compartilhem informações que ajudem a busca.'),
          ),
        if (_error != null)
          ListTile(
            title: Text(_error!),
            trailing: IconButton(
              tooltip: 'Tentar novamente',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ),
        if (!_loading && _error == null && _messages.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Comece a conversa com uma mensagem.'),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final mine =
                        message['sender_id'] ==
                        widget.sessionStore.session?.userId;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(message['body'] as String),
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: const InputDecoration(hintText: 'Mensagem'),
                  ),
                ),
                IconButton(
                  tooltip: 'Enviar mensagem',
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

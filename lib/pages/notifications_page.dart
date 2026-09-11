import 'package:flutter/material.dart';

import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../widgets/app_widgets.dart';
import 'missing_cats_page.dart';
import 'conversation_page.dart';
import 'social_page.dart';
import 'journey_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.store,
    this.initialNotificationId,
  });
  final CatStore store;
  final String? initialNotificationId;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  late final ProductApiService _api;
  bool _openedInitialNotification = false;
  @override
  void initState() {
    super.initState();
    _api = ProductApiService(widget.store.sessionStore);
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _api.list('/vision/notifications');
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
      final initialId = widget.initialNotificationId;
      if (!_openedInitialNotification && initialId != null) {
        _openedInitialNotification = true;
        final matching = items.where((item) => item['id'] == initialId);
        if (matching.isNotEmpty && mounted) await _open(matching.first);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _title(Map<String, dynamic> item) => switch (item['type']) {
    'possible_match' => 'Possível avistamento do seu gato',
    'match_confirmed' => 'Seu avistamento ajudou uma busca',
    'friend_invite' => 'Novo convite de amizade',
    'friend_accepted' => 'Convite de amizade aceito',
    'message' => 'Nova mensagem',
    'achievement' => 'Nova conquista',
    _ => 'Novidade no Gatálogo',
  };
  Future<void> _open(Map<String, dynamic> item) async {
    try {
      await _api.post('/app/notifications/${item['id']}/read');
      final payload = Map<String, dynamic>.from(item['payload'] as Map? ?? {});
      Widget? page;
      if (item['type'] == 'message' && payload['conversation_id'] != null) {
        page = ConversationPage(
          sessionStore: widget.store.sessionStore,
          conversationId: payload['conversation_id'] as String,
        );
      } else if (item['type'] == 'achievement' ||
          item['type'] == 'match_confirmed') {
        page = JourneyPage(store: widget.store);
      } else if (item['type'] == 'possible_match') {
        final matches = await _api.list('/vision/matches');
        final target = matches.where(
          (match) => match['id'] == payload['match_id'],
        );
        if (target.isNotEmpty) {
          final reports = await _api.list('/app/reports');
          final report = reports.where(
            (report) => report['id'] == target.first['report_id'],
          );
          if (report.isNotEmpty) {
            page = CluesPage(
              report: report.first,
              store: widget.store,
              openMatchId: payload['match_id'] as String,
            );
          }
        }
        page ??= MissingCatsPage(
          catStore: widget.store,
          sessionStore: widget.store.sessionStore,
        );
      } else {
        page = Scaffold(
          appBar: AppBar(title: const Text('Amigos')),
          body: SocialPage(sessionStore: widget.store.sessionStore),
        );
      }
      if (mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
      }
      if (mounted) _load();
    } catch (error) {
      if (mounted) showMessage(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notificações'),
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            EmptyContent(
              'Não foi possível carregar',
              _error!,
              action: TextButton(
                onPressed: _load,
                child: const Text('Tentar novamente'),
              ),
            ),
          if (!_loading && _error == null && _items.isEmpty)
            const EmptyContent(
              'Tudo em dia',
              'Novas pistas, mensagens e conquistas aparecerão aqui.',
            ),
          ..._items.map(
            (item) => ListTile(
              leading: Icon(
                item['read_at'] == null
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none,
              ),
              title: Text(
                _title(item),
                style: TextStyle(
                  fontWeight: item['read_at'] == null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              subtitle: Text(displayDate(item['created_at'])),
              onTap: () => _open(item),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
    ),
  );
}

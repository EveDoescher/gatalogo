import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../stores/session_store.dart';
import '../services/social_api_service.dart';
import '../services/websocket_service.dart';

/// Owns conversation state, subscriptions, reconciliation and network commands.
class ConversationController extends ChangeNotifier {
  ConversationController(
    this.session,
    this.conversationId, {
    SocialApiService? api,
    WebSocketService? socket,
    String? username,
    String? otherUserId,
    String? avatarUrl,
    bool isOnline = false,
    bool sightingContext = false,
    this.onScroll,
    this.onClearComposer,
    this.onRestoreComposer,
    this.onError,
  }) : _api = api ?? SocialApiService(session),
       _socket = socket ?? session.webSocket {
    _ownerId = session.session?.userId;
    _username = username;
    _otherUserId = otherUserId;
    _avatarUrl = avatarUrl;
    _isOnline = isOnline;
    _sightingContext = sightingContext;
  }
  final SessionStore session;
  final String conversationId;
  final SocialApiService _api;
  final WebSocketService _socket;
  final ValueChanged<bool>? onScroll;
  final VoidCallback? onClearComposer;
  final ValueChanged<String>? onRestoreComposer;
  final ValueChanged<String>? onError;
  bool _disposed = false;
  late final String? _ownerId;
  bool _inactive = false;
  bool get mounted =>
      !_disposed && !_inactive && session.session?.userId == _ownerId;
  String? get _myUserId => session.session?.userId;
  List<ChatMessage> _messages = [];
  final Set<String> _optimisticIds = {};
  final Set<String> _liveMessageIds = {};
  bool _loading = true, _sending = false, _fetching = false, _amTyping = false;
  String? _error, _username, _otherUserId, _avatarUrl;
  bool _isOnline = false, _sightingContext = false, _otherUserTyping = false;
  DateTime? _lastSeenAt;
  ChatMessage? _replyingTo, _editingMessage;
  Timer? _fallbackPollTimer, _myTypingTimer, _otherTypingDebounceTimer;
  StreamSubscription? _msgSub,
      _typingSub,
      _readSub,
      _presenceSub,
      _reactionSub,
      _editSub,
      _deleteSub;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  Set<String> get optimisticIds => Set.unmodifiable(_optimisticIds);
  bool get loading => _loading;
  bool get sending => _sending;
  String? get error => _error;
  String? get username => _username;
  String? get otherUserId => _otherUserId;
  String? get avatarUrl => _avatarUrl;
  bool get isOnline => _isOnline;
  DateTime? get lastSeenAt => _lastSeenAt;
  bool get sightingContext => _sightingContext;
  bool get otherUserTyping => _otherUserTyping;
  ChatMessage? get replyingTo => _replyingTo;
  set replyingTo(ChatMessage? value) => _update(() => _replyingTo = value);
  ChatMessage? get editingMessage => _editingMessage;
  set editingMessage(ChatMessage? value) =>
      _update(() => _editingMessage = value);
  void _update(VoidCallback action) {
    if (!mounted) return;
    action();
    notifyListeners();
  }

  bool _started = false, _wasConnected = false;
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _wasConnected = _socket.isConnected;
    _socket.addListener(_onConnectionChanged);
    session.addListener(_onAccountChanged);
    _setupRealtime();
    unawaited(load());
  }

  void _onConnectionChanged() {
    if (_socket.isConnected && !_wasConnected) unawaited(load(silent: true));
    _wasConnected = _socket.isConnected;
  }

  void _onAccountChanged() {
    if (!_inactive && session.session?.userId != _ownerId) {
      _inactive = true;
      _stopRealtime();
      _messages = [];
      _optimisticIds.clear();
      _username = _avatarUrl = _otherUserId = null;
      _replyingTo = _editingMessage = null;
      _sending = _loading = _otherUserTyping = _isOnline = false;
      _error = 'Sua conta mudou. Abra a conversa novamente.';
      notifyListeners();
    }
  }

  void _stopRealtime() {
    _fallbackPollTimer?.cancel();
    _myTypingTimer?.cancel();
    _otherTypingDebounceTimer?.cancel();
    for (final sub in [
      _msgSub,
      _typingSub,
      _readSub,
      _presenceSub,
      _reactionSub,
      _editSub,
      _deleteSub,
    ]) {
      sub?.cancel();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _socket.removeListener(_onConnectionChanged);
    session.removeListener(_onAccountChanged);
    _stopRealtime();
    super.dispose();
  }

  Future<void> uploadPhoto(List<int> bytes, String filename) async {
    if (!mounted) return;
    final url = await _api.uploadChatPhoto(conversationId, bytes, filename);
    if (url == null) throw const SocialApiException('Erro ao enviar imagem.');
    if (mounted) await sendMessage(type: 'photo', mediaUrl: url);
  }

  Future<void> deleteMessage(ChatMessage message) async {
    if (!mounted) return;
    _update(
      () => _messages = _messages
          .map(
            (m) => m.id == message.id
                ? m.copyWith(isDeleted: true, body: 'Mensagem apagada')
                : m,
          )
          .toList(),
    );
    try {
      await _api.deleteMessage(conversationId, message.id);
    } catch (error) {
      if (!_disposed) {
        _update(
          () => _messages = _messages
              .map((m) => m.id == message.id ? message : m)
              .toList(),
        );
        onError?.call('Erro ao apagar mensagem: $error');
      }
    }
  }

  void _setupRealtime() {
    final ws = _socket;

    // 1. Mensagens em tempo real pontuais
    _msgSub = ws.onNewMessage.listen((data) {
      if (data['conversation_id'] == conversationId) {
        final newMsg = ChatMessage.fromMap(data);
        _handleIncomingMessage(newMsg);
      }
    });

    // 2. Indicador de digitação
    _typingSub = ws.onTyping.listen((data) {
      if (data['conversation_id'] == conversationId &&
          data['user_id'] != _myUserId) {
        final isTyping = data['is_typing'] == true;
        if (mounted) {
          _update(() {
            _otherUserTyping = isTyping;
          });
        }
        _otherTypingDebounceTimer?.cancel();
        if (isTyping) {
          _otherTypingDebounceTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) _update(() => _otherUserTyping = false);
          });
        }
      }
    });

    // 3. Confirmação de leitura
    _readSub = ws.onMessagesRead.listen((data) {
      if (data['conversation_id'] == conversationId) {
        final readAtStr = data['read_at'];
        final readAt = readAtStr != null
            ? DateTime.tryParse(readAtStr)
            : DateTime.now();
        if (mounted) {
          _update(() {
            _messages = _messages.map((m) {
              if (m.isMine(_myUserId)) {
                return m.copyWith(isRead: true, readAt: readAt);
              }
              return m;
            }).toList();
          });
        }
      }
    });

    // 4. Presença online / visto por último
    _presenceSub = ws.onPresence.listen((data) {
      final userId = data['user_id']?.toString();
      if (userId != null && (_otherUserId == null || userId == _otherUserId)) {
        if (mounted) {
          _update(() {
            _isOnline = data['is_online'] == true;
            if (data['last_seen_at'] != null) {
              _lastSeenAt = DateTime.tryParse(data['last_seen_at'].toString());
            }
          });
        }
      }
    });

    // 5. Reações pontuais
    _reactionSub = ws.onMessageReaction.listen((data) {
      if (data['conversation_id'] == conversationId) {
        final msgId = data['message_id']?.toString();
        final rawMap = data['reactions'] as Map?;
        if (msgId != null && rawMap != null && mounted) {
          _liveMessageIds.add(msgId);
          final updatedReactions = <String, List<String>>{};
          rawMap.forEach((k, v) {
            if (v is List) {
              updatedReactions[k.toString()] = v
                  .map((e) => e.toString())
                  .toList();
            }
          });
          _update(() {
            _messages = _messages.map((m) {
              if (m.id == msgId) {
                return m.copyWith(reactions: updatedReactions);
              }
              return m;
            }).toList();
          });
        }
      }
    });

    // 6. Mensagem editada pontual
    _editSub = ws.onMessageEdited.listen((data) {
      if (data['conversation_id'] == conversationId) {
        final msgId = data['message_id']?.toString();
        final newBody = data['body']?.toString() ?? '';
        if (msgId != null && mounted) {
          _liveMessageIds.add(msgId);
          _update(() {
            _messages = _messages.map((m) {
              if (m.id == msgId) {
                return m.copyWith(body: newBody, isEdited: true);
              }
              return m;
            }).toList();
          });
        }
      }
    });

    // 7. Mensagem apagada pontual
    _deleteSub = ws.onMessageDeleted.listen((data) {
      if (data['conversation_id'] == conversationId) {
        final msgId = data['message_id']?.toString();
        if (msgId != null && mounted) {
          _liveMessageIds.add(msgId);
          _update(() {
            _messages = _messages.map((m) {
              if (m.id == msgId) {
                return m.copyWith(isDeleted: true, body: 'Mensagem apagada');
              }
              return m;
            }).toList();
          });
        }
      }
    });

    // 8. Fallback de polling a cada 30s APENAS se o WebSocket NÃO estiver conectado
    _fallbackPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_socket.isConnected) {
        load(silent: true);
      }
    });
  }

  void _handleIncomingMessage(ChatMessage newMsg) {
    if (!mounted) return;
    _liveMessageIds.add(newMsg.id);
    _update(() {
      final existingIndex = _messages.indexWhere((m) => m.id == newMsg.id);
      if (existingIndex >= 0) {
        _messages[existingIndex] = newMsg;
      } else {
        _messages = [..._messages, newMsg];
      }
    });

    // Se a mensagem for do outro usuário, marcar como lida imediatamente
    if (!newMsg.isMine(_myUserId)) {
      _api.markRead(conversationId);
      _socket.sendRead(conversationId);
    }

    onScroll?.call(true);
  }

  Future<void> load({bool silent = false}) async {
    if (!mounted || _fetching) return;
    _fetching = true;
    _liveMessageIds.clear();
    if (!silent && mounted) _update(() => _loading = true);

    try {
      final detailsFuture = _api.conversationDetails(conversationId);
      final messagesFuture = _api.messages(conversationId);

      final results = await Future.wait([detailsFuture, messagesFuture]);
      final details = results[0] as Map<String, dynamic>;
      final rawMessages = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        _update(() {
          _username = details['username']?.toString() ?? _username;
          _otherUserId = details['other_user_id']?.toString() ?? _otherUserId;
          _avatarUrl = details['avatar_url']?.toString() ?? _avatarUrl;
          if (details['is_online'] != null) {
            _isOnline = details['is_online'] == true;
          }
          if (details['last_seen_at'] != null) {
            _lastSeenAt = DateTime.tryParse(details['last_seen_at'].toString());
          }
          _sightingContext = details['sighting_context'] == true;

          final merged = [
            ...rawMessages.map(ChatMessage.fromMap),
            ..._messages.where(
              (m) =>
                  _optimisticIds.contains(m.id) ||
                  _liveMessageIds.contains(m.id),
            ),
          ];
          _messages = {for (final message in merged) message.id: message}.values
              .toList();
          _error = null;
        });

        // Marcar como lida na abertura
        _api.markRead(conversationId);
        _socket.sendRead(conversationId);
        onScroll?.call(false);
      }
    } catch (error) {
      if (mounted && !silent) _update(() => _error = error.toString());
    } finally {
      _fetching = false;
      if (mounted && !silent) _update(() => _loading = false);
    }
  }

  void onTextChanged(String text) {
    if (!mounted) return;
    if (text.isNotEmpty && !_amTyping) {
      _amTyping = true;
      _socket.sendTyping(conversationId, true);
    }

    _myTypingTimer?.cancel();
    _myTypingTimer = Timer(const Duration(seconds: 3), () {
      if (_amTyping) {
        _amTyping = false;
        _socket.sendTyping(conversationId, false);
      }
    });
  }

  Future<void> sendMessage({
    String body = '',
    String type = 'text',
    String? mediaUrl,
    double? locationLat,
    double? locationLng,
    String? locationTitle,
    Map<String, dynamic>? catData,
  }) async {
    final trimmedBody = body.trim();
    if (type == 'text' && trimmedBody.isEmpty && _editingMessage == null) {
      return;
    }
    if (!mounted || _sending) return;

    // Se estiver no modo de edição de mensagem
    if (_editingMessage != null) {
      await _commitEdit(trimmedBody);
      return;
    }

    final replyId = _replyingTo?.id;
    final replyMap = _replyingTo != null
        ? {
            'id': _replyingTo!.id,
            'sender_id': _replyingTo!.senderId,
            'body': _replyingTo!.previewText,
          }
        : null;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = ChatMessage(
      id: tempId,
      conversationId: conversationId,
      senderId: _myUserId ?? 'me',
      body: trimmedBody,
      type: type,
      mediaUrl: mediaUrl,
      locationLat: locationLat,
      locationLng: locationLng,
      locationTitle: locationTitle,
      catData: catData,
      replyToId: replyId,
      replyTo: replyMap,
      createdAt: DateTime.now(),
    );

    _update(() {
      _sending = true;
      _optimisticIds.add(tempId);
      _messages = [..._messages, optimisticMsg];
      _replyingTo = null;
    });
    onClearComposer?.call();
    onScroll?.call(true);

    // Notificar fim de digitação
    if (_amTyping) {
      _amTyping = false;
      _socket.sendTyping(conversationId, false);
    }

    try {
      final sentData = await _api.sendMessage(
        conversationId,
        body: trimmedBody,
        type: type,
        mediaUrl: mediaUrl,
        locationLat: locationLat,
        locationLng: locationLng,
        locationTitle: locationTitle,
        catData: catData,
        replyToId: replyId,
      );

      final realMsg = ChatMessage.fromMap(sentData);
      _liveMessageIds.add(realMsg.id);
      if (mounted) {
        _update(() {
          _optimisticIds.remove(tempId);
          _messages = {
            for (final m in _messages)
              (m.id == tempId ? realMsg.id : m.id): (m.id == tempId
                  ? realMsg
                  : m),
          }.values.toList();
        });
      }
    } on SocialApiException catch (error) {
      _rollbackOptimistic(tempId, trimmedBody, error.message);
    } catch (e) {
      _rollbackOptimistic(tempId, trimmedBody, 'Erro ao enviar mensagem: $e');
    } finally {
      if (mounted) _update(() => _sending = false);
    }
  }

  void _rollbackOptimistic(
    String tempId,
    String originalText,
    String errorMsg,
  ) {
    if (!mounted) return;
    _update(() {
      _messages = _messages.where((m) => m.id != tempId).toList();
      _optimisticIds.remove(tempId);
      if (originalText.isNotEmpty) onRestoreComposer?.call(originalText);
    });
    onError?.call(errorMsg);
  }

  Future<void> _commitEdit(String newBody) async {
    final target = _editingMessage;
    if (target == null) return;

    _update(() {
      _editingMessage = null;
      _sending = true;
    });
    onClearComposer?.call();

    try {
      final updated = await _api.editMessage(
        conversationId,
        target.id,
        newBody,
      );
      final updatedMsg = ChatMessage.fromMap(updated);
      if (mounted) {
        _update(() {
          _messages = _messages
              .map((m) => m.id == target.id ? updatedMsg : m)
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        onError?.call('Erro ao editar mensagem: $e');
      }
    } finally {
      if (mounted) _update(() => _sending = false);
    }
  }

  Future<void> toggleReaction(ChatMessage msg, String reaction) async {
    if (!mounted) return;
    // Atualização otimista
    final myId = _myUserId ?? 'me';
    final currentList = List<String>.from(msg.reactions[reaction] ?? []);
    final alreadyReacted = currentList.contains(myId);

    if (alreadyReacted) {
      currentList.remove(myId);
    } else {
      currentList.add(myId);
    }

    final newReactions = Map<String, List<String>>.from(msg.reactions);
    if (currentList.isEmpty) {
      newReactions.remove(reaction);
    } else {
      newReactions[reaction] = currentList;
    }

    _update(() {
      _messages = _messages
          .map((m) => m.id == msg.id ? m.copyWith(reactions: newReactions) : m)
          .toList();
    });

    try {
      await _api.toggleMessageReaction(conversationId, msg.id, reaction);
    } catch (_) {
      // Reverte em caso de falha de rede
      if (mounted) {
        _update(() {
          _messages = _messages.map((m) => m.id == msg.id ? msg : m).toList();
        });
      }
    }
  }
}

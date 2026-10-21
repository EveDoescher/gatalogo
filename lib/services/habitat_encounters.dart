part of 'habitat_service.dart';

extension HabitatEncounters on HabitatService {
  Future<void> checkVisitors() async {
    if (!session.isSignedIn || offline || hasDraft || _visitorRequest) return;
    _visitorRequest = true;
    final owner = _ownerId;
    try {
      final result = await _repository.visitors();
      if (owner != _ownerId || _disposed) return;
      final draft = hasDraft ? _draft() : null;
      _readSnapshot(result);
      if (draft != null) _applyDraft(draft);
      await _persistSnapshot();
      _notifyVisitors();
    } on ProductApiException {
      /* Visitors never interrupt normal Quintal use. */
    } finally {
      _visitorRequest = false;
    }
  }

  Future<Map<String, dynamic>> giftAction(String action) async {
    final gift = pendingGift;
    if (_visitorRequest) {
      throw const ProductApiException(
        'Aguarde a atualização do quintal e tente novamente.',
      );
    }
    if (gift == null || !session.isSignedIn || offline) {
      throw const ProductApiException('Conecte-se para recolher o presente.');
    }
    _visitorRequest = true;
    final owner = _ownerId;
    try {
      final result = await _repository.gift(gift['id'].toString(), action);
      if (_disposed || owner != _ownerId) {
        throw const ProductApiException(
          'Sua conta mudou. Abra o Quintal novamente.',
        );
      }
      final draft = hasDraft ? _draft() : null;
      _readSnapshot(result);
      if (draft != null) _applyDraft(draft);
      await _persistSnapshot();
      _notifyVisitors();
      return Map<String, dynamic>.from(result['gift_reward'] as Map? ?? {});
    } finally {
      _visitorRequest = false;
    }
  }
}

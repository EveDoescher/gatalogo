class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    this.type = 'text',
    this.mediaUrl,
    this.locationLat,
    this.locationLng,
    this.locationTitle,
    this.catData,
    this.readAt,
    this.isRead = false,
    this.replyToId,
    this.replyTo,
    this.reactions = const {},
    this.isEdited = false,
    this.isDeleted = false,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final String type;
  final String? mediaUrl;
  final double? locationLat;
  final double? locationLng;
  final String? locationTitle;
  final Map<String, dynamic>? catData;
  final DateTime? readAt;
  final bool isRead;
  final String? replyToId;
  final Map<String, dynamic>? replyTo;
  final Map<String, List<String>> reactions;
  final bool isEdited;
  final bool isDeleted;
  final DateTime createdAt;

  bool get isPhoto => type == 'photo';
  bool get isLocation => type == 'location';
  bool get isCatCard => type == 'cat_card';
  bool get isText => type == 'text' || (!isPhoto && !isLocation && !isCatCard);

  bool isMine(String? myUserId) => myUserId != null && senderId == myUserId;

  String get previewText {
    if (isDeleted) return 'Mensagem apagada';
    if (isPhoto) return body.isNotEmpty ? 'Foto: $body' : 'Foto';
    if (isLocation) {
      final loc = locationTitle ?? 'Localização';
      return body.isNotEmpty ? '$loc ($body)' : loc;
    }
    if (isCatCard) {
      final name = catData?['name'] ?? 'Gato';
      return 'Ficha de $name';
    }
    return body;
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value == null) return DateTime.now();
      try {
        return DateTime.parse(value.toString()).toLocal();
      } catch (_) {
        return DateTime.now();
      }
    }

    final reactionsRaw = map['reactions'];
    final reactionsMap = <String, List<String>>{};
    if (reactionsRaw is Map) {
      reactionsRaw.forEach((key, val) {
        if (val is List) {
          reactionsMap[key.toString()] = val.map((e) => e.toString()).toList();
        }
      });
    }

    final replyToRaw = map['reply_to'];
    Map<String, dynamic>? replyTo;
    if (replyToRaw is Map) {
      replyTo = Map<String, dynamic>.from(replyToRaw);
    }

    final catDataRaw = map['cat_data'];
    Map<String, dynamic>? catData;
    if (catDataRaw is Map) {
      catData = Map<String, dynamic>.from(catDataRaw);
    }

    final readAtVal = map['read_at'];
    final readAt = readAtVal != null ? parseDate(readAtVal) : null;
    final isRead = readAt != null || map['is_read'] == true;

    return ChatMessage(
      id: map['id']?.toString() ?? '',
      conversationId: map['conversation_id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      type: map['type']?.toString() ?? 'text',
      mediaUrl: map['media_url']?.toString(),
      locationLat: (map['location_lat'] as num?)?.toDouble(),
      locationLng: (map['location_lng'] as num?)?.toDouble(),
      locationTitle: map['location_title']?.toString(),
      catData: catData,
      readAt: readAt,
      isRead: isRead,
      replyToId: map['reply_to_id']?.toString(),
      replyTo: replyTo,
      reactions: reactionsMap,
      isEdited: map['is_edited'] == true,
      isDeleted: map['is_deleted'] == true,
      createdAt: parseDate(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'body': body,
      'type': type,
      'media_url': ?mediaUrl,
      'location_lat': ?locationLat,
      'location_lng': ?locationLng,
      'location_title': ?locationTitle,
      'cat_data': ?catData,
      'read_at': ?readAt?.toIso8601String(),
      'is_read': isRead,
      'reply_to_id': ?replyToId,
      'reply_to': ?replyTo,
      'reactions': reactions,
      'is_edited': isEdited,
      'is_deleted': isDeleted,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? body,
    String? type,
    String? mediaUrl,
    double? locationLat,
    double? locationLng,
    String? locationTitle,
    Map<String, dynamic>? catData,
    DateTime? readAt,
    bool? isRead,
    String? replyToId,
    Map<String, dynamic>? replyTo,
    Map<String, List<String>>? reactions,
    bool? isEdited,
    bool? isDeleted,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      body: body ?? this.body,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      locationTitle: locationTitle ?? this.locationTitle,
      catData: catData ?? this.catData,
      readAt: readAt ?? this.readAt,
      isRead: isRead ?? this.isRead,
      replyToId: replyToId ?? this.replyToId,
      replyTo: replyTo ?? this.replyTo,
      reactions: reactions ?? this.reactions,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

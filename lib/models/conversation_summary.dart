import 'chat_message.dart';

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.otherUserId,
    required this.otherUsername,
    this.otherAvatarUrl,
    this.isOnline = false,
    this.lastSeenAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.sightingContext = false,
    this.matchSuggestionId,
    required this.updatedAt,
  });

  final String id;
  final String otherUserId;
  final String otherUsername;
  final String? otherAvatarUrl;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final bool sightingContext;
  final String? matchSuggestionId;
  final DateTime updatedAt;

  String get formattedTime {
    final now = DateTime.now();
    final dt = updatedAt.toLocal();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return 'Ontem';
    }
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d/$mo';
  }

  factory ConversationSummary.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value == null) return DateTime.now();
      try {
        return DateTime.parse(value.toString()).toLocal();
      } catch (_) {
        return DateTime.now();
      }
    }

    final otherUser = map['other_user'] as Map<String, dynamic>? ?? {};
    final otherUserId = otherUser['id']?.toString() ?? map['other_user_id']?.toString() ?? '';
    final otherUsername = otherUser['username']?.toString() ??
        map['other_username']?.toString() ??
        map['username']?.toString() ??
        'amigo';
    final otherAvatar = otherUser['avatar_url']?.toString() ??
        map['other_avatar_url']?.toString() ??
        map['avatar_url']?.toString();
    final isOnline = otherUser['is_online'] == true || map['is_online'] == true;
    final lastSeenRaw = otherUser['last_seen_at'] ?? map['last_seen_at'];
    final lastSeenAt = lastSeenRaw != null ? parseDate(lastSeenRaw) : null;

    final lastMsgRaw = map['last_message'];
    ChatMessage? lastMsg;
    if (lastMsgRaw is Map) {
      lastMsg = ChatMessage.fromMap(Map<String, dynamic>.from(lastMsgRaw));
    }

    return ConversationSummary(
      id: map['id']?.toString() ?? '',
      otherUserId: otherUserId,
      otherUsername: otherUsername,
      otherAvatarUrl: otherAvatar,
      isOnline: isOnline,
      lastSeenAt: lastSeenAt,
      lastMessage: lastMsg,
      unreadCount: (map['unread_count'] as num?)?.toInt() ?? 0,
      sightingContext: map['sighting_context'] == true,
      matchSuggestionId: map['match_suggestion_id']?.toString(),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'other_user': {
        'id': otherUserId,
        'username': otherUsername,
        'avatar_url': ?otherAvatarUrl,
        'is_online': isOnline,
        'last_seen_at': ?lastSeenAt?.toIso8601String(),
      },
      'last_message': ?lastMessage?.toMap(),
      'unread_count': unreadCount,
      'sighting_context': sightingContext,
      'match_suggestion_id': ?matchSuggestionId,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class Mission {
  final String id;
  final String title;
  final int target;
  final int progress;
  final int xpReward;
  final bool completed;

  const Mission({
    required this.id,
    required this.title,
    required this.target,
    required this.progress,
    required this.xpReward,
    required this.completed,
  });

  factory Mission.fromMap(Map<String, dynamic> map) {
    return Mission(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      target: (map['target'] as num?)?.toInt() ?? 1,
      progress: (map['progress'] as num?)?.toInt() ?? 0,
      xpReward: (map['xp_reward'] as num?)?.toInt() ?? 0,
      completed: map['completed'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'target': target,
      'progress': progress,
      'xp_reward': xpReward,
      'completed': completed,
    };
  }

  double get progressFraction =>
      target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

  Mission copyWith({
    String? id,
    String? title,
    int? target,
    int? progress,
    int? xpReward,
    bool? completed,
  }) {
    return Mission(
      id: id ?? this.id,
      title: title ?? this.title,
      target: target ?? this.target,
      progress: progress ?? this.progress,
      xpReward: xpReward ?? this.xpReward,
      completed: completed ?? this.completed,
    );
  }
}

class GamificationState {
  final int xp;
  final int level;
  final String levelTitle;
  final int levelMinXp;
  final int targetXp;
  final String levelReward;
  final int streak;
  final int longestStreak;
  final double multiplier;
  final int freezeShields;
  final String? lastActionDate;
  final List<Mission> dailyMissions;
  final Mission? weeklyMission;
  final Mission? bonusMission;
  final int unlockedAchievements;
  final int totalAchievements;

  const GamificationState({
    required this.xp,
    required this.level,
    required this.levelTitle,
    required this.levelMinXp,
    required this.targetXp,
    required this.levelReward,
    required this.streak,
    required this.longestStreak,
    required this.multiplier,
    required this.freezeShields,
    this.lastActionDate,
    required this.dailyMissions,
    this.weeklyMission,
    this.bonusMission,
    required this.unlockedAchievements,
    required this.totalAchievements,
  });

  factory GamificationState.initial() {
    return const GamificationState(
      xp: 0,
      level: 1,
      levelTitle: 'Curioso',
      levelMinXp: 0,
      targetXp: 100,
      levelReward: 'Início da jornada felina',
      streak: 0,
      longestStreak: 0,
      multiplier: 1.0,
      freezeShields: 1,
      dailyMissions: [
        Mission(
          id: 'daily_photo',
          title: 'Fotografar ou catalogar 1 gato',
          target: 1,
          progress: 0,
          xpReward: 60,
          completed: false,
        ),
        Mission(
          id: 'daily_social',
          title: 'Interagir em 2 publicações da comunidade',
          target: 2,
          progress: 0,
          xpReward: 40,
          completed: false,
        ),
        Mission(
          id: 'daily_care',
          title: 'Verificar área de busca ou atualizar fotos',
          target: 1,
          progress: 0,
          xpReward: 50,
          completed: false,
        ),
      ],
      weeklyMission: Mission(
        id: 'weekly_sightings',
        title: 'Registrar avistamentos em 3 dias diferentes',
        target: 3,
        progress: 0,
        xpReward: 150,
        completed: false,
      ),
      bonusMission: Mission(
        id: 'bonus_share',
        title: 'Compartilhar uma descoberta ou cartaz de desaparecimento',
        target: 1,
        progress: 0,
        xpReward: 80,
        completed: false,
      ),
      unlockedAchievements: 0,
      totalAchievements: 28,
    );
  }

  factory GamificationState.fromMap(Map<String, dynamic> map) {
    final dailyList = (map['daily_missions'] as List?)
            ?.whereType<Map>()
            .map((m) => Mission.fromMap(Map<String, dynamic>.from(m)))
            .toList() ??
        [];
    final weeklyMap = map['weekly_mission'] is Map
        ? Map<String, dynamic>.from(map['weekly_mission'] as Map)
        : null;
    final bonusMap = map['bonus_mission'] is Map
        ? Map<String, dynamic>.from(map['bonus_mission'] as Map)
        : null;

    return GamificationState(
      xp: (map['xp'] as num?)?.toInt() ??
          (map['new_xp'] as num?)?.toInt() ??
          0,
      level: (map['level'] as num?)?.toInt() ?? 1,
      levelTitle: map['level_title']?.toString() ?? 'Curioso',
      levelMinXp: (map['level_min_xp'] as num?)?.toInt() ?? 0,
      targetXp: (map['target_xp'] as num?)?.toInt() ?? 100,
      levelReward: map['level_reward']?.toString() ?? 'Início da jornada felina',
      streak: (map['streak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longest_streak'] as num?)?.toInt() ?? 0,
      multiplier: (map['multiplier'] as num?)?.toDouble() ?? 1.0,
      freezeShields: (map['freeze_shields'] as num?)?.toInt() ?? 1,
      lastActionDate: map['last_action_date']?.toString(),
      dailyMissions: dailyList.isNotEmpty
          ? dailyList
          : GamificationState.initial().dailyMissions,
      weeklyMission: weeklyMap != null
          ? Mission.fromMap(weeklyMap)
          : GamificationState.initial().weeklyMission,
      bonusMission: bonusMap != null
          ? Mission.fromMap(bonusMap)
          : GamificationState.initial().bonusMission,
      unlockedAchievements:
          (map['unlocked_achievements'] as num?)?.toInt() ?? 0,
      totalAchievements: (map['total_achievements'] as num?)?.toInt() ?? 28,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'xp': xp,
      'level': level,
      'level_title': levelTitle,
      'level_min_xp': levelMinXp,
      'target_xp': targetXp,
      'level_reward': levelReward,
      'streak': streak,
      'longest_streak': longestStreak,
      'multiplier': multiplier,
      'freeze_shields': freezeShields,
      'last_action_date': lastActionDate,
      'daily_missions': dailyMissions.map((m) => m.toMap()).toList(),
      'weekly_mission': weeklyMission?.toMap(),
      'bonus_mission': bonusMission?.toMap(),
      'unlocked_achievements': unlockedAchievements,
      'total_achievements': totalAchievements,
    };
  }

  double get progressFraction {
    final range = targetXp - levelMinXp;
    if (range <= 0) return 1.0;
    return ((xp - levelMinXp) / range).clamp(0.0, 1.0);
  }

  int get currentLevelXp => (xp - levelMinXp).clamp(0, targetXp - levelMinXp);
  int get currentLevelTargetXp => (targetXp - levelMinXp).clamp(1, 999999);
}

class GamificationActionResult {
  final GamificationState state;
  final int earnedXp;
  final double multiplier;
  final bool levelUp;
  final int level;
  final String levelTitle;
  final List<String> missionsCompleted;

  const GamificationActionResult({
    required this.state,
    required this.earnedXp,
    required this.multiplier,
    required this.levelUp,
    required this.level,
    required this.levelTitle,
    required this.missionsCompleted,
  });
}

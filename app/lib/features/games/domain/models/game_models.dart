import 'package:equatable/equatable.dart';

/// Game model
class Game extends Equatable {
  final String id;
  final String name;
  final String description;
  final String? icon;
  final String route;
  final DateTime createdAt;

  const Game({
    required this.id,
    required this.name,
    required this.description,
    this.icon,
    required this.route,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, name, description, icon, route, createdAt];
}

/// Highscore model
class Highscore extends Equatable {
  final String id;
  final String gameId;
  final int score;
  final DateTime achievedAt;
  final Map<String, dynamic>? metadata;

  const Highscore({
    required this.id,
    required this.gameId,
    required this.score,
    required this.achievedAt,
    this.metadata,
  });

  @override
  List<Object?> get props => [id, gameId, score, achievedAt, metadata];
}

/// Game session model
class GameSession extends Equatable {
  final String id;
  final String gameId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? finalScore;
  final Map<String, dynamic>? sessionData;

  const GameSession({
    required this.id,
    required this.gameId,
    required this.startedAt,
    this.endedAt,
    this.finalScore,
    this.sessionData,
  });

  /// Check if session is active
  bool get isActive => endedAt == null;

  /// Get session duration
  Duration get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  @override
  List<Object?> get props => [
        id,
        gameId,
        startedAt,
        endedAt,
        finalScore,
        sessionData,
      ];
}

/// Achievement model
class Achievement extends Equatable {
  final String id;
  final String gameId;
  final String name;
  final String description;
  final String? icon;
  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.gameId,
    required this.name,
    required this.description,
    this.icon,
    this.unlocked = false,
    this.unlockedAt,
  });

  @override
  List<Object?> get props => [
        id,
        gameId,
        name,
        description,
        icon,
        unlocked,
        unlockedAt,
      ];
}


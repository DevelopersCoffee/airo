import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import '../../domain/services/chess_engine.dart';
import '../flame/chess_game.dart';

/// Chess game screen with difficulty selection
class ChessGameScreenNew extends ConsumerStatefulWidget {
  final ChessDifficulty? initialDifficulty;

  const ChessGameScreenNew({super.key, this.initialDifficulty});

  @override
  ConsumerState<ChessGameScreenNew> createState() => _ChessGameScreenNewState();
}

class _ChessGameScreenNewState extends ConsumerState<ChessGameScreenNew> {
  ChessDifficulty? _selectedDifficulty;

  @override
  void initState() {
    super.initState();
    _selectedDifficulty = widget.initialDifficulty;
  }

  @override
  Widget build(BuildContext context) {
    // Show difficulty selection if not selected
    if (_selectedDifficulty == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chess Master'), centerTitle: true),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.games, size: 64, color: Colors.brown[700]),
              const SizedBox(height: 24),
              const Text(
                'Select Difficulty',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              _buildDifficultyButton(
                context,
                ChessDifficulty.easy,
                'Easy',
                'Perfect for beginners',
                Colors.green,
              ),
              const SizedBox(height: 16),
              _buildDifficultyButton(
                context,
                ChessDifficulty.medium,
                'Medium',
                'Balanced challenge',
                Colors.orange,
              ),
              const SizedBox(height: 16),
              _buildDifficultyButton(
                context,
                ChessDifficulty.hard,
                'Hard',
                'Advanced level',
                Colors.red,
              ),
              const SizedBox(height: 16),
              _buildDifficultyButton(
                context,
                ChessDifficulty.expert,
                'Expert',
                'World Champion (ELO 3600+)',
                Colors.purple,
              ),
            ],
          ),
        ),
      );
    }

    // Show game
    return Scaffold(
      appBar: AppBar(
        title: Text('Chess - ${_selectedDifficulty!.name.toUpperCase()}'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _selectedDifficulty = null;
              });
            },
          ),
        ],
      ),
      body: GameWidget(game: ChessGameFlame(difficulty: _selectedDifficulty!)),
    );
  }

  Widget _buildDifficultyButton(
    BuildContext context,
    ChessDifficulty difficulty,
    String label,
    String description,
    Color color,
  ) {
    return SizedBox(
      width: 280,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: () {
          setState(() {
            _selectedDifficulty = difficulty;
          });
        },
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

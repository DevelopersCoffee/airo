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
  bool _shuffleSides = false;
  ChessGameFlame? _game;

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
              const SizedBox(height: 16),
              // Shuffle sides toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Random side:',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _shuffleSides,
                    onChanged: (value) {
                      setState(() {
                        _shuffleSides = value;
                      });
                    },
                  ),
                  Text(
                    _shuffleSides ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _shuffleSides ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
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

    // Create game instance if needed
    _game ??= ChessGameFlame(
      difficulty: _selectedDifficulty!,
      shuffleSides: _shuffleSides,
    );

    // Show game
    return Scaffold(
      appBar: AppBar(
        title: Text('Chess - ${_selectedDifficulty!.name.toUpperCase()}'),
        centerTitle: true,
        actions: [
          // Flip board button
          IconButton(
            icon: const Icon(Icons.swap_vert),
            tooltip: 'Flip board',
            onPressed: () {
              _game?.flipBoard();
            },
          ),
          // New game button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New game',
            onPressed: () {
              setState(() {
                _selectedDifficulty = null;
                _game = null;
              });
            },
          ),
        ],
      ),
      body: GameWidget(game: _game!),
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

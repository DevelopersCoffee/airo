# Chess Audio Assets

This directory contains audio files for the Chess Master game.

## Directory Structure

```
audio/
├── pieces/
│   ├── pawn/
│   │   ├── quiet.mp3
│   │   ├── capture.mp3
│   │   ├── check.mp3
│   │   └── checkmate.mp3
│   ├── knight/
│   │   ├── quiet.mp3
│   │   ├── capture.mp3
│   │   ├── check.mp3
│   │   └── checkmate.mp3
│   ├── bishop/
│   │   ├── quiet.mp3
│   │   ├── capture.mp3
│   │   ├── check.mp3
│   │   └── checkmate.mp3
│   ├── rook/
│   │   ├── quiet.mp3
│   │   ├── capture.mp3
│   │   ├── check.mp3
│   │   └── checkmate.mp3
│   ├── queen/
│   │   ├── quiet.mp3
│   │   ├── capture.mp3
│   │   ├── check.mp3
│   │   └── checkmate.mp3
│   └── king/
│       ├── quiet.mp3
│       ├── capture.mp3
│       ├── check.mp3
│       └── checkmate.mp3
├── stingers/
│   ├── capture.mp3
│   ├── check.mp3
│   └── checkmate.mp3
└── music/
    ├── opening.mp3
    ├── midgame.mp3
    └── endgame.mp3
```

## Voice Lines

Each piece type has voice lines for different move classifications:

### Pawn
- **quiet**: "A footsoldier did that.", "Pawn power.", "One step at a time."
- **capture**: "Pawn takes!", "Eliminated!", "Footsoldier's revenge!"
- **check**: "Check!", "King's in trouble!", "Watch out!"
- **checkmate**: "Checkmate!", "Victory!", "Game over!"

### Knight
- **quiet**: "Two problems. One horse.", "Knight moves in mysterious ways.", "L-shaped destiny."
- **capture**: "Knight's fork!", "Captured!", "Tactical strike!"
- **check**: "Check from the knight!", "Unexpected check!", "Horse power!"
- **checkmate**: "Knight's mate!", "Checkmate!", "Victory!"

### Bishop
- **quiet**: "Geometry hurts.", "Diagonal domination.", "The bishop has spoken."
- **capture**: "Diagonal strike!", "Captured!", "Bishop takes!"
- **check**: "Check!", "Diagonal threat!", "Watch the diagonals!"
- **checkmate**: "Checkmate!", "Victory!", "Game over!"

### Rook
- **quiet**: "Corridor secured.", "Straight and narrow.", "Rook solid."
- **capture**: "Rook captures!", "Eliminated!", "Straight through!"
- **check**: "Check!", "Rook's threat!", "Watch the files!"
- **checkmate**: "Checkmate!", "Victory!", "Game over!"

### Queen
- **quiet**: "The queen reigns supreme.", "Royal flush.", "Majesty in motion."
- **capture**: "Queen takes!", "Eliminated!", "Royal power!"
- **check**: "Check!", "Queen's threat!", "Beware the queen!"
- **checkmate**: "Checkmate!", "Victory!", "Game over!"

### King
- **quiet**: "That tickled.", "The king moves.", "Royalty in retreat."
- **capture**: "King captures!", "Eliminated!", "Royal strike!"
- **check**: "Check!", "King under attack!", "Escape!"
- **checkmate**: "Checkmate!", "Victory!", "Game over!"

## Background Music

- **opening.mp3**: Calm, exploratory music for the opening phase (moves 1-10)
- **midgame.mp3**: Tension-building music for the midgame phase (moves 11-30)
- **endgame.mp3**: Heroic, dramatic music for the endgame phase (moves 30+)

## Stingers

- **capture.mp3**: Sharp, decisive sound for piece captures
- **check.mp3**: Alert, warning sound for check situations
- **checkmate.mp3**: Victory fanfare for checkmate

## Audio Generation

To generate these audio files, you can use:

1. **Text-to-Speech**: Use Google Cloud TTS, Azure Speech, or similar services
2. **Sound Effects**: Use Freesound.org, Zapsplat, or similar libraries
3. **Music**: Use royalty-free music from Incompetech, Epidemic Sound, or similar

## Implementation Notes

- All audio files should be in MP3 format for compatibility
- Recommended bitrate: 128 kbps for voice, 192 kbps for music
- Voice lines should be 1-3 seconds long
- Stingers should be 0.5-1 second long
- Background music should be loopable and 30-60 seconds long

## Testing

The game will gracefully handle missing audio files by logging errors and continuing gameplay.


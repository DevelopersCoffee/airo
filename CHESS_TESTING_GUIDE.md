# Chess Master - Testing Guide

## Build & Deploy

### 1. Build the App
```bash
cd app
flutter clean
flutter pub get
flutter run -d "192.168.1.77:33535"
```

### 2. Verify Build Success
- App should compile without errors
- App should install on Pixel 9 device
- App should launch to home screen

## Testing the Chess Game

### 1. Navigate to Chess Game
1. Open the app on Pixel 9
2. Tap the **Games** tab (bottom navigation)
3. You should see the Games Hub with tiles
4. Tap the **Chess Master** tile

### 2. Difficulty Selection Screen
You should see:
- Chess icon at the top
- "Select Difficulty" title
- Three buttons: Easy, Medium, Hard
- Each button shows difficulty name and description

**Test**: Tap each difficulty button to verify they work

### 3. Game Screen
After selecting difficulty, you should see:
- AppBar with "Chess - [DIFFICULTY]" title
- Refresh button in top-right
- Flame game widget with chess board

### 4. Chess Board
The board should display:
- 8x8 grid with alternating light/dark squares
- Chess pieces in starting positions (Unicode symbols)
- White pieces at bottom, Black at top

**Piece Symbols**:
- ♟ = Pawn
- ♞ = Knight
- ♝ = Bishop
- ♜ = Rook
- ♛ = Queen
- ♚ = King

### 5. Gameplay Testing

#### Test Move Selection
1. Tap a white piece (e.g., pawn on e2)
2. The piece should highlight in yellow
3. Legal moves should show in green
4. Tap a legal move destination
5. Piece should move to that square

#### Test AI Response
1. After you move, wait 500ms
2. AI should automatically make a move
3. Black piece should move on the board

#### Test Difficulty Levels
- **Easy**: AI makes random moves (may move pieces suboptimally)
- **Medium**: AI makes reasonable moves
- **Hard**: AI plays optimally

#### Test Reset
1. Tap the refresh button in AppBar
2. Should return to difficulty selection screen
3. Select a different difficulty to start new game

### 6. Audio Testing (When Audio Files Added)

#### Expected Audio Behavior
1. **Move Audio**: When a piece moves, you should hear:
   - Piece-specific voice line (e.g., "Knight moves in mysterious ways")
   - Background music continues

2. **Capture Audio**: When a piece is captured:
   - Piece voice line for capture
   - Capture stinger sound

3. **Check Audio**: When king is in check:
   - Check stinger sound
   - Piece voice line

4. **Checkmate Audio**: When game ends:
   - Checkmate stinger
   - Victory fanfare

5. **Background Music**: Should transition based on move count:
   - Moves 1-10: Calm opening music
   - Moves 11-30: Tense midgame music
   - Moves 30+: Heroic endgame music

### 7. Performance Testing

#### Check Performance
1. Play several moves
2. Monitor device performance:
   - No frame drops
   - Smooth piece rendering
   - Responsive touch input
   - No memory leaks

#### Check Logs
```bash
adb logcat -s flutter
```

Look for:
- No error messages
- Audio loading messages (when audio files added)
- Game state transitions

### 8. Edge Cases to Test

1. **Rapid Taps**: Tap multiple squares quickly
   - Should handle gracefully
   - Only valid moves should execute

2. **Tap Outside Board**: Tap outside the 8x8 grid
   - Should be ignored
   - No errors in logs

3. **Deselect Piece**: Select a piece, then tap empty square
   - Piece should deselect
   - No moves should execute

4. **Select Opponent Piece**: Try to select black piece
   - Should not be selectable
   - No moves should show

## Audio Asset Setup (Optional)

To add actual audio files:

1. **Create Audio Files**
   - Use TTS for voice lines
   - Use sound effects libraries for stingers
   - Use royalty-free music for background

2. **Place in Assets**
   ```
   app/assets/audio/
   ├── pieces/
   │   ├── pawn/
   │   │   ├── quiet.mp3
   │   │   ├── capture.mp3
   │   │   ├── check.mp3
   │   │   └── checkmate.mp3
   │   ├── knight/
   │   ├── bishop/
   │   ├── rook/
   │   ├── queen/
   │   └── king/
   ├── stingers/
   │   ├── capture.mp3
   │   ├── check.mp3
   │   └── checkmate.mp3
   └── music/
       ├── opening.mp3
       ├── midgame.mp3
       └── endgame.mp3
   ```

3. **Rebuild App**
   ```bash
   flutter clean
   flutter pub get
   flutter run -d "192.168.1.77:33535"
   ```

## Troubleshooting

### Build Fails
- Run `flutter clean`
- Delete `android/.gradle` and `build/` directories
- Run `flutter pub get`
- Try building again

### App Crashes on Chess Screen
- Check logs: `adb logcat -s flutter`
- Verify Flame dependencies are installed
- Ensure chess_game.dart has no syntax errors

### No Audio Playing
- Verify audio files exist in `assets/audio/`
- Check device volume is not muted
- Check logs for audio loading errors
- Verify pubspec.yaml includes audio assets

### Pieces Not Rendering
- Check device supports Vulkan rendering
- Try on different device
- Check Flame version compatibility

### Touch Input Not Working
- Verify device touch screen is working
- Try tapping different areas of board
- Check for touch event logs

## Success Criteria

✅ App builds without errors
✅ Chess game screen loads
✅ Difficulty selection works
✅ Board renders correctly
✅ Pieces display with correct symbols
✅ Touch input selects pieces
✅ Moves execute correctly
✅ AI makes moves after player
✅ Difficulty levels affect AI behavior
✅ Reset button returns to difficulty selection
✅ No crashes or errors in logs

## Next Steps

1. Generate/add audio files
2. Implement real chess engine
3. Add move validation
4. Add game state persistence
5. Add multiplayer support
6. Add statistics tracking

